# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 9)

## Context

- **Audit date**: 2026-08-16
- **Round**: 9 -- **Round type: full** (all 11 lenses ran; see `lenses-run.txt`)
- **Round purpose**: post-remediation verification of Stages A/B/C (`82d9081..bffbc5c`)
- **Audited scope**: `plugins/edm/**` (`bin/`, `bin/tests/`, `evals/`, `hooks/`, `skills/`, `agents/`, `docs/`), repository-root `.gitlab-ci.yml` and `CLAUDE.md`, and `SRD/edm/EDMV3__prompt-streamline/` (srd.md, ticket pack, decisions.md)
- **SRD**: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.3.0)
- **Ticket pack**: `SRD/edm/EDMV3__prompt-streamline/tickets/`
- **Ledger**: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (authoritative; `findings-ledger.md` is rendered by `edm-state render-ledger`)
- **Deployment target**: local + GitLab CI (the plugin ships no runtime service)

### Delivery degradation this round (from `tooling-notes.md`, CA-466)

**All eleven lenses were interrupted mid-run by the driving account's API spend limit and resumed
from their own transcripts** (stalls: L8 x3; L2, L9, L10, L11 x2; L1, L3, L4, L5, L6, L7 x1) --
no lens restarted from scratch and **no lens shipped a scope-truncation caveat**, so every report
is complete over its mandate. Separately, **CA-130 recurred for a 9th-to-10th consecutive round on
every lens**: no lens was delivered `Write` or `Bash`, so all eleven reports were returned inline
and persisted by the orchestrator, **every Priority-1 remediation verdict below is derived from
reading the tree at HEAD rather than from `git log`/`git diff` over `833a06d..HEAD`**, and the
2182/0 suite figure quoted to the lenses was orchestrator-supplied and independently unverified.
Two findings (CA-501's mode bit, CA-505's rendered column offsets) are explicitly marked as
"would have been settled by one command" and carry reduced confidence for that reason.

### Round-9 disposition of the Stage A/B/C wave

**57 findings closed** (`resolved_round: 9`). Every closure is backed by at least one lens's
Priority-1 verification table. Of these, **CA-472 had no ledger line at all** -- it was raised and
remediated inside the remediation batch itself, which is CA-416's class one level up; it is
recorded retroactively and closed in the same round.

**Four fixes introduced new defects**, filed under new IDs per the ledger's standing rule (do not
reopen the parent):

| Parent fix | New defect | New ID |
|---|---|---|
| CA-440 (hook QC shard) | shard namespace collision with the threshold shards | **CA-473** (P1) |
| CA-437 (NUL extraction) | `read -d` bashism in a blocking CI job | **CA-474** (P1) |
| CA-448 (project-root anchoring) | `CLAUDE_PROJECT_DIR` trusted unvalidated | **CA-500** |
| CA-471 (completeness gate) | unterminated-line skip, ambiguous glob, irreversible downgrade, no owning AC, no mutation-proof test | **CA-478, CA-479, CA-506, CA-510, CA-477** |

**17 of the 57 closures carry `spec_swept: "no"`** -- the remediating commit did not sweep every
AC, comment or doc passage naming the changed behaviour. That is not a bookkeeping detail: it is
the direct, measured cause of **nine** of this round's findings (CA-475, CA-483, CA-484, CA-485,
CA-487, CA-490, CA-494, CA-507, CA-508, CA-509). CA-416 -- the finding that asked for this field
and its enforcement -- **remains open**, and L9 confirms only its prose half shipped.

---

## Findings Summary

**52 open** (0 P0, 7 P1, 45 P2) + 1 new NOTED. New this round: CA-473..CA-512.

### P1 (7)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-473 | P1 | **L1+L3** | `skills/implement/SKILL.md:97,:101` vs `hooks/hooks.json:117` | CA-440's fix put two writers with incompatible keys into one `qc-shard-NN.md` namespace; FAIL verdicts still silently overwritten |
| CA-474 | P1 | **L8+L1** | `.gitlab-ci.yml:301` | CA-437's fix put a `read -d` bashism in the only blocking job whose own comment forbids bash constructs; fails closed with the wrong diagnostic |
| CA-475 | P1 | **L6+L9** | `evals/baseline/README.md:50`; `epics/03:495` | CA-462's 6th scorer dimension shipped unswept: the baseline runbook's gating instruction is unsatisfiable and T23 AC1/AC2/AC8/AC9/AC10 are false |
| CA-476 | P1 | L11 | `bin/edm-state:5137` | `update-patterns` extracts a heading level no report produces: 22 scaffolding entries polluted the shipped library; 3 of 4 arms record `0` forever |
| CA-477 | P1 | L4 | `bin/tests/wave6-smoke.sh:877` | The new CA-471 gate survives two one-line mutations with all six assertions green; the motivating class (*missing*) is untested |
| CA-416 | P1 | L9 | ledger entry template (carried, r7) | `spec_swept` shipped as prose only -- no mechanism, no smoke case, no `audit-converged` check; still the root cause |
| CA-424 | P1 | L9 | `epics/04:560` (carried, r8, narrowed) | T28 AC12's amendment landed but its own `Verify:` cites `T-EDMV4`, a label the same batch relabelled out of existence |

### P2 -- new this round (34)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-483 | P2 | **L6+L7+L9+L11** | `CLAUDE.md:61` | Root registry still `v3.1.0` against three sources saying `3.2.0`; second occurrence of CA-127 with nothing pinning it |
| CA-478 | P2 | **L1+L3** | `bin/edm-state:4460` | CA-471's manifest loop drops an unterminated final line -- on a full round that is L11; CRLF disables the gate wholesale |
| CA-481 | P2 | **L3+L7+L8**(L5 dissent) | `evals/tiering-matrix.sh:154`; `evals/score-artifacts.sh:756` | Unswept sites of the just-closed CA-446/447 class, plus the prescribed sweep assertion that never landed |
| CA-482 | P2 | **L3+L7** (L1 dissent) | `bin/edm-lint-artifacts:137` | CA-447's own new first-stage trap is the cleanup-then-resume shape it closed 12 lines below; 5 more sites in `bin/tests/` |
| CA-484 | P2 | **L6+L11** | `evals/score-artifacts.sh:4` | Header says "exactly five dimensions" 18 lines above its own help text saying six (outside the `EDM-HELP` sentinel) |
| CA-491 | P2 | **L4+L1** | `bin/tests/wave7-smoke.sh:364` | CA-441's `Task` rule shipped with no must-fail case; its only coverage is an assertion the rule cannot influence |
| CA-496 | P2 | **L7+L11** | `bin/tests/wave7-smoke.sh:5900` | CLI-family durability loop omits `edm-lint-staged-artifacts`, the tenth helper added by CA-436 itself |
| CA-497 | P2 | **L7+L8** | `bin/edm-lint-staged-artifacts:25` | Only `set -uo pipefail` site with no rationale; "normalizing" it to `-euo` silently disables commit lint for everyone |
| CA-501 | P2 | **L8+L11** | `bin/edm-lint-staged-artifacts` (mode) | Commit-time enforcement depends on an executable bit nothing asserts, on a delegate nothing ever runs |
| CA-479 | P2 | L3 | `bin/edm-state:4453` | CA-471's pass-dir glob keeps the last of several matches silently -- spurious downgrade or vacuous pass |
| CA-480 | P2 | L3 | `bin/edm-state:1348` | A lockdir with no pidfile is never reclaimed; on the macOS mkdir branch that bricks the initiative permanently |
| CA-511 | P2 | L3 | `.gitlab-ci.yml:713` | Inner phase-timeout budget (136m) uncoupled from the 150m job timeout; kills CA-452's handshake when it matters |
| CA-485 | P2 | L6 | `.gitlab-ci.yml:353`; `plugins/edm/CLAUDE.md:1020` | Two unswept CA-463 siblings still call the evals budget a "directory-size ceiling" |
| CA-486 | P2 | L6 | `plugins/edm/CLAUDE.md:1021` | `lint:shellcheck` row omits `*.awk` from the exclusion list its sibling row states correctly |
| CA-487 | P2 | L6 | `plugins/edm/CLAUDE.md:883` | CA-407 residual: durability note names the wrong test file and a grep that matches no call site |
| CA-488 | P2 | L6 | `plugins/edm/README.md:205` | `decisions.md` listed "optional on-demand"; the layout marks it Must/always-present and the code-audit skill requires it |
| CA-489 | P2 | L6 | `docs/audit-patterns/README.md:48` | Documented pending-count command is a bare `grep -c` over a glob and does not produce a count |
| CA-490 | P2 | L2 | `bin/edm-compare-eval:58` | CA-452 residual: the un-armed-baseline check precedes condition 3, so the `complete:false` handshake is unreachable |
| CA-492 | P2 | L4 | `bin/tests/wave6-smoke.sh:811` | The CA-426 fixture positively pins zero-round convergence with no companion case stating the boundary |
| CA-493 | P2 | L4 | `.gitlab-ci.yml:524` | `test:state-validate` is blocking and prints `OK` after validating nothing, with no floor |
| CA-494 | P2 | L4 | `.gitlab-ci.yml:748` | CA-443 residual: `eval:nightly` still skips scoring *and* comparison silently for every other cause |
| CA-495 | P2 | L5 | `bin/tests/wave7-smoke.sh:7272` | G22b's scratch tree is never removed on any path; 11 siblings sit outside the trap-covered root |
| CA-498 | P2 | L7 | `bin/edm-check-grants:515` | `Task` rule landed without the `Skill` rule the same contract names -- the argument CA-441 rejected |
| CA-499 | P2 | L8 | `bin/edm-lint-staged-artifacts:1` | Only hardcoded-interpreter shebang in the plugin, on the file the commit hook routes all enforcement through |
| CA-500 | P2 | L8 | `bin/edm-state:1062`, `:1697` | CA-448 residual: `CLAUDE_PROJECT_DIR` trusted on a bare `-d` test; a bypass that records itself as enforced |
| CA-502 | P2 | L10 | `.gitlab-ci.yml:106`, `:242`; `wave7-smoke.sh:1081` | The bash-source file set is written 3x and has already diverged; the CA-233 pin covers only the exclusion arm |
| CA-503 | P2 | L10 | `bin/edm-state:4358` | The audit-type enum is hand-written 6x against the file's own documented single-source convention |
| CA-504 | P2 | L10 | `bin/edm-state:4903` | CA-419 residual: `_cmd_set_provenance_field` omits `write_handoff_internal`, leaving HANDOFF.md stale |
| CA-505 | P2 | L10 | `bin/edm-state:1116` | CA-418 residual: Coverage width declared twice and the two disagree; the extraction's own claim is false |
| CA-506 | P2 | L11 | `skills/code-audit/SKILL.md:147` | The CA-471 downgrade is irreversible but step 9a prescribes a repair loop with no terminus |
| CA-507 | P2 | L11 | `skills/code-audit/SKILL.md:347` | CA-466's `tooling-notes.md` consumer lives only in the agent definition, not the operative spawn prompt |
| CA-508 | P2 | L9 | `tickets/README.md:12` | CA-430 residual: nine pack statistics still assert 67 tickets; T68 has no Mermaid node and reintroduces a retired convention conflict |
| CA-509 | P2 | L9 | `srd.md:3836` | The pack asserts an SRD amendment that does not exist; `srd.md` EDMV3-90 is byte-unchanged at v1.3.0 |
| CA-510 | P2 | L9 | `bin/edm-state:4438`; `SKILL.md:104` | CA-471's convergence-blocking refusal has no owning AC and both candidate owners disclaim it |

### P2 -- carried forward, re-verified still open (11)

| # | Sev | Lens(es) | Component | Issue | Raised |
|---|-----|----------|-----------|-------|--------|
| CA-401 | P2 | L4+L1 | `wave6-smoke.sh:290,:1057,:1074,:3441,:3448,:3460` | Unguarded `grep -c` captures under `set -euo pipefail`; **D60 debt** | r7 |
| CA-402 | P2 | L4 | `wave7-smoke.sh:2044-2045` | Repo-wide scans that self-match; five divergent exclusion vocabularies; **D60 debt** | r7 |
| CA-403 | P2 | L4 | `wave7-smoke.sh:963,:1137,:1284,:1294,:1304,:1442` | Six positive controls derived from the pattern, not the regression; **D60 debt** | r7 |
| CA-404 | P2 | L4 | `wave7-smoke.sh:607,:635,:648,:678` | Scorer exit status discarded at four extraction sites; **D60 debt** | r7 |
| CA-405 | P2 | L4 | `wave7-smoke.sh:2547` | T44 AC8 meta-assertion passes with 39 of 40 assertions deleted; **D60 debt** | r7 |
| CA-414 | P2 | L8 | `bin/edm-lint-staged-artifacts:101` | **Narrowed**: `printf`-for-`echo` half closed; `core.quotePath=false` rests on a false premise (only `-z` suppresses C-quoting of `"`, `\`, control bytes) | r7 |
| CA-453 | P2 | L4+L1 | `bin/tests/` | CA-389/CA-390's four prescribed assertions still absent; **D60 debt** | r8 |
| CA-455 | P2 | -- | lock-contract cases | Three lock-contract test cases missing; **D60 debt** | r8 |
| CA-456 | P2 | -- | HANDOFF renderer | Eight-cell row contract unpinned; **D60 debt** | r8 |
| CA-457 | P2 | L4 | control arm coverage | Arm-coverage axis of the control-quality class; **D60 debt** | r8 |
| CA-459 | P2 | L4+L10 | `_harness.sh:237-256` | `count_matches` exit-2 collapse false-pass direction; **D60 debt** | r8 |

**D60 debt set (10 entries: CA-401..405, 453, 455, 456, 457, 459)** stays open by documented
decision and is not re-litigated here. L4 records that the class **acquired new sites this batch**
(`wave7-smoke.sh:8167-8168`, `:8227`) without requesting a new ID.

---

## Detailed Findings

### CA-473 (P1, lenses L1 + L3): CA-440's fix relocated the QC-verdict overwrite rather than removing it

**Problem**: CA-440 correctly stopped 6-10 concurrent hook-spawned auditors from all writing
`qc/qc-summary.md`. The replacement writes `qc/qc-shard-{NN}.md` -- but the pre-existing
threshold-shard mechanism already owns that namespace with an **incompatible key**:

| Writer | Key for `{NN}` | Site |
|---|---|---|
| Hook-spawned per-implementer auditor | **lowest ticket number** in the range | `hooks.json:117`, restated `SKILL.md:81-83` |
| Skill's post-wave QC, `ticket_count <= threshold` | **lowest ticket number** | `SKILL.md:97` |
| Skill's post-wave QC, sharded branch | **shard ordinal** `{i+1:02d}` | `SKILL.md:101` |

All three are two-digit zero-padded, written into one directory with full-file `Write` semantics
by concurrently running agents, and `SKILL.md:103` merges both sets through a single
`qc-shard-*.md` glob -- while `SKILL.md:87` states the two mechanisms run *separately from* each
other. Two deterministic collisions: **(a) small initiative** (`ticket_count <= qc_shard_threshold`,
default 20) -- `:97` uses a key byte-identical to the hook's, so the skill's single orchestrated
auditor overwrites the hook shard for the implementer owning that lowest ticket, every time;
**(b) large initiative** -- threshold shard 1 collides with the implementer whose range begins at
T01 (essentially always present), shard 2 with T02, and so on. Last writer wins; the loser's FAIL
verdicts never reach `SKILL.md:119`'s compile step. Only PARTIAL verdicts reach state through the
correctly-locked `record-partial-verdict`, so **PASS and FAIL live only in these markdown files**.
Same harm CA-440 was rated P1 for, at reduced blast radius (one shard, not all).

**Fix**:
1. `hooks.json:117` step 5 -- write `qc/qc-shard-impl-{NN}.md` (NN = lowest ticket number), and
   say so in the same sentence that currently says `qc-shard-{NN}.md`.
2. `skills/implement/SKILL.md:97` and `:101` -- write `qc/qc-shard-pass-{i+1:02d}.md`, using
   `qc-shard-pass-01.md` for the single-auditor branch so the two branches of one mechanism agree.
3. `skills/implement/SKILL.md:103` -- merge `qc-shard-impl-*.md` **and** `qc-shard-pass-*.md`.
4. `skills/implement/SKILL.md:81-85` and `plugins/edm/CLAUDE.md`'s `SubagentStop` hooks-table row
   -- state both prefixes and that they must not overlap.

**Verification**: add a `wave7-smoke.sh` assertion that the shard token in `hooks.json`'s
`SubagentStop` prompt and the shard token in `skills/implement/SKILL.md`'s pseudo-code are **not
equal**, with a positive control that sets them equal and turns red. Manually: run a wave covering
T01-T09 with `qc_shard_threshold` at its default and confirm `qc/` holds
`qc-shard-impl-01/04/07.md` plus `qc-shard-pass-01.md` with no filename reused.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/skills/implement/SKILL.md`,
`plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md` artifact-layout block
(`qc/qc-shard-{NN}.md`) and its `SubagentStop` hooks-table row; `agents/edm-qc-auditor.md:81`;
`bin/edm-state:2388-2395`'s phase-6 completion acceptance of either filename. T02's Target
Components is **not** in scope -- `tickets/README.md:57` declares that field drift-tolerant by
design (L9 cleared it).

---

### CA-474 (P1, lenses L8 + L1): CA-437's fix put the pipeline's only bashism in its only blocking hook-lint job

**Problem**: `.gitlab-ci.yml:301` iterates the new NUL-delimited extraction with
`while IFS= read -r -d '' cmd; do`. `read -d` is a bash extension with no POSIX equivalent --
`dash` has no `-d`, and BusyBox `ash` (the shell in the `alpine:3.20` images every
`<<: *alpine_edm` consumer uses) supports `-r -n -p -s -t -u` but not `-d`. A sweep of every
`script:` body in the file for `[[`, `local`, `<<<`, `mapfile`, `declare`, array syntax and
`read -d` returns **exactly one hit: line 301**. The file states the opposing constraint three
times, once inside this very job's own header at `:274-276` ("process substitution needs bash
itself as the invoking shell, which is not guaranteed for the runner's script stage"), again at
`:517-519` and `:566-568`. `apk add bash` in `before_script` does not change which interpreter the
runner already selected for the script stage. On an `sh` runner: `read` rejects `-d`, the `while`
condition is false immediately (errexit does not apply to a loop condition), the body never runs,
`COUNT` stays `0`, and the CA-437 cross-check at `:320` fails the job with
`checked 0 command(s) but hooks.json declares 9 (extraction/splitting regression, CA-437)` --
fail-closed but **actively misdiagnosing**, on a `needs: []`, no-`allow_failure` job that gates the
plugin's most privileged shell surface and has never had a green run against a live runner fleet.

**Fix** -- drop the delimiter question entirely by indexing with `jq` (pure POSIX, immune to every
splitting question including the multi-line `.command` case CA-437 was about, and makes the count
cross-check structural rather than post-hoc):

```sh
EXPECTED_COUNT="$(jq '[.hooks|to_entries[]|.value[]|.hooks[]|select(.type=="command")]|length' plugins/edm/hooks/hooks.json)"
IDX=0
while [ "$IDX" -lt "$EXPECTED_COUNT" ]; do
  jq -r --argjson n "$IDX" \
    '[.hooks|to_entries[]|.value[]|.hooks[]|select(.type=="command")][$n].command' \
    plugins/edm/hooks/hooks.json > "${TMP}/hook-${IDX}.sh"
  # ... existing bash -n / shellcheck body, unchanged ...
  IDX=$((IDX + 1)); COUNT=$((COUNT + 1))
done
```

Keep the `:320` cross-check; retarget its message at a jq/index mismatch. **Only if** the runner
fleet is confirmed to resolve bash for the script stage, the alternative is to pin `shell: bash` on
the `.alpine_edm` anchor **and delete the three POSIX-sh-safe comments as false** -- do not leave
the file asserting one thing and doing another.

**Verification**: `sh -n` the extracted `script:` block (it must parse under POSIX sh);
then `docker run --rm -v "$PWD":/w -w /w alpine:3.20 sh -c '<the job body>'` and confirm
`COUNT` reaches 9. Re-run `lint:hooks-shell` in CI.

**Files affected**: `.gitlab-ci.yml`.

**Spec/AC text to sweep in the same commit**: `.gitlab-ci.yml:274-276`, `:517-519`, `:566-568`
(the three POSIX-sh-safe claims -- keep them true or delete them); `plugins/edm/CLAUDE.md`'s
`lint:hooks-shell` CI-table row; T56/T57's `lint:hooks-shell` ACs if they name the extraction shape.

---

### CA-475 (P1, lenses L6 + L9): CA-462's sixth scorer dimension shipped without its runbook or its ACs

**Problem**: `evals/score-artifacts.sh:145` now declares six `DIM_NAMES` ending in
`known-gap-recall`, with `SCORER_VERSION="1.1.0"` at `:137` and `compute_dim6` at `:546-574` gated
only on `run.json`'s `.fixture == "tiny-svc"` -- which `run-eval.sh` writes on **both** the complete
path (`:675`) and the partial path (`:152`). A wave-A capture therefore scores dimensions 1, 2, 3,
4 and 6 and skips only 5, so `dimensions_scored` is **5**. Two artifact families are now false:

*(a) The baseline-capture runbook*, `evals/baseline/README.md`, was edited **twice in this same
batch** (CA-461 at `:107-112`, CA-464 at `:11-14`) without sweeping the dimension count.
`:50-51` is the file's one gating instruction -- "confirm all three runs have `complete: true` and
`dimensions_scored: 4` before using any of them as the committed baseline" -- and **can no longer
be satisfied**. Also stale: `:56` ("Why four dimensions, not five"), `:62-63`, `:63-67`, the
`:77-84` variance table (no `known-gap-recall` row), the `:95-105` `per_dimension_range` example,
`:116` and `:119`. `evals/README.md` **was** swept correctly (`:197-199`, `:217-220`), which makes
this a miss rather than a convention. The failure mode is silent and expensive: an operator spends
three live model runs (the README's own estimate: roughly $10-25 and 30-60 minutes each), reads
`dimensions_scored: 5`, and concludes the capture is broken -- or hand-"corrects" it.

*(b) EDMV3-T23's acceptance criteria* (`epics/03:495-517`, `:546-555`, `:558-562`): AC1 requires
"exactly five" and verifies with `jq -e '.dimensions | length == 5'`, which now returns **false**;
AC2 enumerates only dimensions 1-5; AC8 requires a committed four-dimension baseline with
`dimensions_scored: 4` plus a `grep -n 'four-dimension'` and is **unsatisfiable by construction**;
AC9/AC10 both say five. **No AC anywhere** owns `known-gap-recall`, `expected.json`'s new
`srd_match` patterns, `fixture_version 1.1.0`, or `run.json`'s new `fixture` field.
`score-artifacts.sh:38-39` *acknowledges the AC conflict in a code comment* while no ticket, AC or
`decisions.md` entry records it.

**Blocking coupling**: `wave7-smoke.sh:830` and `:834` assert the literal string `four-dimension`
against this README, so the stale text is currently **pinned green by the suite** -- the doc fix
cannot land without the test edit in the same commit.

**Fix** (one commit):
1. `evals/baseline/README.md` -- rewrite as a **five-scored / one-skipped** wave-A baseline
   (dimensions 1-4 and 6 score; dimension 5 is null on every wave-A run because `run-eval.sh` stops
   after `audit-srd`); add the `known-gap-recall` row to the `:77-84` variance table and to the
   `:95-105` `per_dimension_range` example; correct `:116` and `:119` to six.
2. `epics/03` T23 -- AC1 to "exactly six" with the new verify literal (`length == 6`); add
   dimension 6's definition to AC2; rewrite AC8 as a five-dimension wave-A baseline
   (`dimensions_scored: 5`, `dimensions_skipped | length == 1`, grep literal updated); correct
   AC9/AC10.
3. Add an AC (T22 or T23) owning `srd_match`, `fixture_version` and `run.json.fixture`.
4. `wave7-smoke.sh:830`, `:834` -- update to the new literal **in the same commit**.
5. Fold in **CA-484** (`score-artifacts.sh:4`).

**Verification**: `bash plugins/edm/evals/score-artifacts.sh --describe | grep -c '^ *[0-9]\.'`
returns 6; the T23 AC1 verify command returns true;
`grep -rn 'four-dimension\|dimensions_scored: 4' plugins/edm/evals SRD/edm/EDMV3__prompt-streamline/tickets`
returns nothing; `bash plugins/edm/bin/tests/run-all.sh` stays green.

**Files affected**: `plugins/edm/evals/baseline/README.md`,
`plugins/edm/evals/score-artifacts.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/03-ci-and-fixture-eval.md`.

**Spec/AC text to sweep in the same commit**: T23 AC1/AC2/AC8/AC9/AC10; T22 AC2;
`evals/baseline/README.md` (8 sites listed above); `evals/score-artifacts.sh:4`;
`decisions.md` (record the dimension-count change and its authorization).

---

### CA-476 (P1, lens L11): `update-patterns` harvests structural scaffolding, and three of its four arms are dead

**Problem**: `cmd_update_patterns` is the **sole** mechanism by which the cross-initiative pattern
library accumulates knowledge -- called from four skills (`code-audit` step 9a, `audit-srd`,
`audit-tickets`, `test-coverage`) and read by all eleven lens agents. `bin/edm-state:5137` extracts
finding titles with `grep '^### '`, and **no report format this methodology produces puts finding
titles at that level**. For the `code` arm, `skills/code-audit/SKILL.md`'s own Remediation Plan
Format puts finding titles at `##` and reserves `###` for the `Problem`/`Fix`/`Verification`/`Files`
sub-blocks. The live consequence is committed and visible: `docs/audit-patterns/code-audit.md:101-322`
holds **22 machine-appended `###` entries**, all `source: EDMV3`, `date: 2026-08-16`,
`status: pending-review`, with titles like `Syntax / static`, `Test suites`, `Lint / contract
checks`, `Targeted re-audit (round 9)`, `WORK ITEM 4 onward -- P2 detail` and `P0 (0)`. They sit
under `## Anti-Patterns` alongside the five real hand-authored entries at `:72-96`, so the library's
largest section is now **roughly 80% non-patterns**, in a shipped plugin asset that thirteen prompt
surfaces are pointed at as accumulated wisdom. The `srd`, `ticket` and `qc` arms contain **zero**
`###` headings of any kind, so those three arms record `new_findings: 0` on every run, permanently,
and print `no novel findings to append` -- indistinguishable from a genuinely clean round.

False Alarm Filter fails on all three clauses: `docs/audit-patterns/README.md:30-35` specifies only
the *destination* shape, so the source-side `###` rule is an undocumented implementation choice; the
stop-word list at `:5126` (`summary|findings|recommendations|overview|appendix|legend`) shows
structural leakage was anticipated but is a six-string blocklist against an unbounded space and
covers **none** of the 22 that landed; and this is the only extractor.

**Fix**:
1. Make the extraction heading level **per audit type**. For `code`: `^## ` filtered to the
   finding-block shape (`## CA-NNN` / `## G{N} (`), excluding the six fixed structural headings the
   Remediation Plan Format defines (`Context`, `Findings Summary`, `Detailed Findings`,
   `Decisions / Non-Findings`, `Rollout Order`, `Verification Plan`).
2. For `srd` / `ticket` / `qc`: those reports are **tables, not headings**, so a heading-based
   extractor cannot work at all -- either read the table rows, or make those three arms `die`
   loudly rather than record `new_findings: 0`.
3. **Revert the 22 polluted entries** out of `docs/audit-patterns/code-audit.md` in the same commit
   (delete `:101-322`, preserving `:72-96` and the `## Pre-Flight Checklist` boundary at `:323`).

**Verification**: add a `wave7-smoke.sh` case feeding a synthetic report in **each of the five
formats** and asserting the extracted set equals the finding titles and **excludes** the structural
headings, with a positive control. Then
`grep -c '^### ' plugins/edm/docs/audit-patterns/code-audit.md` returns 5.
Existing coverage (CA-002, CA-056, CA-355) exercises insertion *mechanics* and never asserts *what*
gets extracted.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/docs/audit-patterns/code-audit.md`,
`plugins/edm/docs/audit-patterns/README.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `docs/audit-patterns/README.md`'s Append Schema
(`:30-35`) must state the **source-side** heading rule per audit type, not only the destination
shape; `bin/edm-state:4972-4975`'s contract comment; `skills/code-audit/SKILL.md:467-468`'s
curation-drain note (L11 N4 -- benign once this is fixed).

---

### CA-477 (P1, lens L4): the new CA-471 gate survives two one-line mutations with every assertion green

**Problem**: `wave6-smoke.sh:866-910` covers `bin/edm-state:4449-4472`. Two independent mutations
leave all six CA-471 assertions -- and the whole suite -- passing.

*(a) Unconditional downgrade.* Moving `ca471_downgrade="partial"` (`edm-state:4469`) out of the
`if [[ -n "$_missing" ]]` guard makes **every** code round with a pass directory record
`round_type=partial`, so **no initiative can ever converge again** -- and nothing fails, because the
only fully-backed case (`CA471OK`) is started with `--lenses L1,L2` at `:875`, so its round is
*already* partial, and its sole assertion at `:877` is a `check_absent` on the warn text, never on
`round_type`. No case anywhere completes a **full** round with all JSONL present and asserts
`round_type` is still `full` afterwards; T27's three `round_type=full` assertions (`:3234`, `:3251`,
`:3259`) are all taken immediately after `audit-round-start`, never after `audit-round-complete`.

*(b) Deleted JSON-validity arm.* Deleting `|| ! jq empty "$_lens_file"` from `edm-state:4463` also
leaves all six green, because the only miss fixture (`:884`) is an **empty** file (`: >`), which the
sibling `[[ ! -s ]]` catches alone. Of the three classes the gate's own comment claims at
`edm-state:4442` (missing / empty / unparseable) only **empty** is exercised -- and the motivating
regression was **missing**: pass-7 shipped eleven prose reports and zero JSONL.

**Fix**:
1. Add a case that runs `audit-round-start <PFX> code` with **no** `--lenses`, lands a parseable
   JSONL for every lens in the manifest, runs `audit-round-complete`, and asserts
   `round_type == "full"` **after** completion.
2. Split the miss fixture into three lenses -- one file absent, one empty (`: >`), one
   present-but-unparseable (`printf 'not json\n'`) -- and assert all three lens IDs appear in the
   single warn's `for: ` list.

**Verification**: apply each mutation by hand and confirm the suite now fails, naming the case;
revert and confirm green. Pair with **CA-478**'s no-trailing-newline case in the same block.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: the new ACs added under **CA-510** (T51) must be the
labels these cases cite verbatim, per `tickets/README.md:73-81`.

---

### CA-478 (P2, lenses L1 + L3): the CA-471 gate skips the last lens when the manifest has no trailing newline

**Problem**: `bin/edm-state:4460` reads the manifest with a bare
`while IFS= read -r _lens; do ... done < "$_manifest"`. `read` returns non-zero at EOF on an
unterminated final line, so **the loop body never executes for that line**. This input class is
unique in the tree: `lenses-run.txt` is the one manifest authored by an **LLM agent via the `Write`
tool** (`skills/code-audit/SKILL.md:78`), whereas every other `done < "$file"` reader consumes a
`printf`-generated file (`edm-check-grants:562`), repo-committed config
(`edm-check-vocabulary:158`, `:233`) or JSONL (`score-artifacts.sh:500`). The consequence sits at
the worst spot: on a **full** round the last manifest line is `L11`, and a round that truncated its
delivery is exactly the round most likely to be missing its *last* lens. Such a round reports no
misses, records `round_type: full`, and can converge -- reproducing the pass-7 failure CA-471 exists
to prevent. **Secondary**: a CRLF manifest fails `^L[0-9]+$` on *every* line and disables the gate
wholesale with no diagnostic. Undetectable today because `wave6-smoke.sh:870`/`:881` seed the
manifest with a trailing-newline `printf`.

**Fix** (`bin/edm-state:4460-4461`):

```bash
while IFS= read -r _lens || [[ -n "$_lens" ]]; do
  _lens="${_lens%$'\r'}"
  [[ "$_lens" =~ ^L[0-9]+$ ]] || continue
```

**Verification**: add to the CA-471 block in `wave6-smoke.sh` -- seed a manifest with
`printf 'Round type: full\nL1\nL2'` (no final newline) plus only `lens-L1.jsonl`, and assert the
warn names `L2`. Add a CRLF variant asserting the gate still fires.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: n/a (the gate's own comment at `:4442` already
describes the contract correctly; only the implementation is short of it).

---

### CA-479 (P2, lens L3): the CA-471 pass-directory glob resolves ambiguously and silently

**Problem**: `bin/edm-state:4453-4457` walks `"${_init_dir}/code-audit/pass-${round_num}_"*` and
keeps the **last** match with no diagnostic. A re-run across a date boundary, a hand-copied scratch
directory, or a partially-created retry yields two matches, and both directions fail silently: if
the newest lacks lens JSONL the gate fires **spuriously** and downgrades a complete round to
`partial` -- which CA-506 shows is **irreversible** -- and if the newest is stale but holds JSONL
the gate passes **vacuously** for the round that actually ran. The C-4 carve-out at `:4445-4447`
tolerates a *missing* directory and says nothing about an *ambiguous* one. (`round_num` itself is
safe: the glob prefix is fully quoted.)

**Fix**: collect matches into a counted array; when `>1`, emit a warning naming **all** of them and
select by mtime (or refuse outright) rather than resolving silently.

**Verification**: a `wave6-smoke.sh` case creating `pass-1_2026-08-16/` and `pass-1_2026-08-17/`
and asserting the warn names both directories and the selection is deterministic.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: the C-4 clause in `bin/edm-state:4445-4447` and in
the new T51 AC (CA-510) must state the ambiguous case alongside the missing case.

---

### CA-480 (P2, lens L3): a lockdir with no pidfile is never reclaimed and permanently bricks the initiative

**Problem**: at `bin/edm-state:1348`, the **entire** reclaim apparatus -- both the age-gated
invalid-PID path (`:1350-1383`) and the dead-PID path (`:1385-1398`) -- lives inside
`if [[ -f "$pidfile" ]]`. A lockdir that exists *without* a pidfile skips the whole block on every
iteration, falls through to `_lock_retry_or_die`, exhausts the ~100-try/10s budget and dies.
Nothing on this or any later invocation can reclaim it. Reachable via **(a)** a crash, `kill -9` or
power loss between `mkdir "$lockdir"` succeeding (`:1343`) and the pidfile write (`:1404`) -- and
the trap layer is not installed until `:1425`, so even a *clean* `INT` in that window orphans it;
**(b)** the pidfile write failing at all, since `:1404` ends `2>/dev/null || true` and swallows
EROFS/ENOSPC/quota; **(c)** any external process creating the directory name. `mkdir` is the
**macOS** branch and CLAUDE.md names macOS the primary development platform, so once bricked every
`edm-state` mutation for that initiative dies -- including the `Stop`/`PreCompact`
`checkpoint-if-active` hooks that fire every session -- until a human runs `rm -rf`.
**Corroborating tell**: the invalid-PID branch already prints `'${holder_pid:-missing}'` at
`:1375`, `:1377`, `:1379`, and that `missing` arm is unreachable as written -- the `-f` guard means
`holder_pid` can only be empty when the pidfile *exists* and is empty. The author intended coverage;
the guard placement prevents it.

**Fix**: hoist the age-gated reclaim **out** of the `-f "$pidfile"` branch so an absent pidfile
takes the same age-gated path an empty/invalid one does; and make the `:1404` write failure fatal
(remove the lockdir, then `die`) instead of `|| true`.

**Verification**: a `wave7-smoke.sh` case creating a lockdir with no pidfile, back-dating it past
the age gate, and asserting `edm-state set` reclaims it and succeeds; plus a second case with a
read-only lockdir asserting the write failure `die`s rather than proceeding silently.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: the lock-contract prose at `bin/edm-state:1287-1300`
and the `plugins/edm/CLAUDE.md` locking section, if either states that a stale lockdir is always
reclaimable. Overlaps the open **CA-455** (missing lock-contract test cases, D60 debt).

---

### CA-481 (P2, lenses L3 + L7 + L8; L5 dissent overruled): unswept sites of the just-closed trap class

**Problem**: three parts of one class.
**(a)** `evals/tiering-matrix.sh:154` -- `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` is one body
on all signals with **no exit** (CA-446's cleanup-then-resume shape) **and omits HUP entirely** (the
half CA-447 added everywhere else). `evals/*.sh` is inside both findings' declared scope; the file
was simply never visited. Its own comment at `:148-153` explains the `RETURN` reasoning and
predates the convention, so nothing signals the divergence as deliberate.
**(b)** `evals/score-artifacts.sh:756-757` still has an untrapped one-`mktemp` window -- the exact
gap `edm-lint-artifacts:133-137` just closed.
**(c)** CA-447's **prescribed durability pin never landed**: `bin/tests/` contains no `CA-446` or
`CA-447` assertion at all, so the convention is stated in one comment in one file
(`edm-check-grants:124-130`, which now declares the four-signal set **plugin-wide**) and enforced
nowhere -- which is precisely why (a) and (b) survived a sweep that named them in scope.

**Cross-lens disagreement, resolved**: L5 N1 would hold `tiering-matrix.sh:154` under **CA-291**'s
do-not-re-file disposition. **Overruled**: CA-446/CA-447's remediation *changed the premise* --
`edm-check-grants:124-130` now asserts the four-signal set as a plugin-wide convention and nine
sibling sites were converted, so this is no longer an unremarkable outlier but the **single declared
exception to a declared rule**. L5's own report calls it "the last trap in the plugin omitting HUP".
L3, L7 and L8 all filed it independently.

**Fix**: convert `:154` to the canonical four-arm form (`EXIT` cleanup-only; `INT` + `exit 130`;
`TERM` + `exit 143`; `HUP` + `exit 129`), keeping `RETURN` on the EXIT-equivalent arm; arm a
first-stage trap immediately after `score-artifacts.sh`'s first `mktemp`; and land CA-447's sweep
assertion.

**Verification**: the new sweep assertion -- scan `bin/`, `bin/tests/` and `evals/` for cleanup
`trap` lines, assert each names `HUP` and each real signal exits after cleanup, with a positive
control that removes `HUP` from one site and turns red. This assertion also verifies **CA-482**.

**Files affected**: `plugins/edm/evals/tiering-matrix.sh`, `plugins/edm/evals/score-artifacts.sh`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-check-grants:124-130`'s plugin-wide claim
(it must become true, or name its exceptions); **CA-291**'s NOTED disposition in the ledger is
superseded by this entry and should not be cited again for this site.

---

### CA-482 (P2, lenses L3 + L7; L1 dissent recorded): CA-447's own new trap is the shape CA-446 closed

**Problem**: `bin/edm-lint-artifacts:137` arms
`trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP` -- one body, four signals, **no exit** -- the
exact CA-446 cleanup-then-resume shape closed **twelve lines below at `:149-152`**, directly above
that file's own `:145-148` comment declaring "the three real signals now exit with signal-shaped
codes after cleanup". It contradicts the contract `bin/edm-state:687-691` states file-wide. A signal
in the covered window (the second `mktemp` at `:144`) cleans up and **resumes** -- and this binary
runs on every `git commit` via the `PreToolUse` hook, so the interrupt an operator sends is the one
that gets swallowed. **Five more sites** (folded in from L7 P2-4 rather than filed separately):
`bin/tests/_harness.sh:85`, `_harness.sh:114`, `harness-smoke.sh:264`, `wave6-smoke.sh:34`,
`wave7-smoke.sh:25` -- while `timing.sh:49-52` in the same directory uses the four-line form, so the
exit-arm half is applied at 7 of 13 sites. For `wave7-smoke.sh:25` the resume is concretely wrong: a
Ctrl-C deletes `$TMP` and the suite continues running assertions against a tree that no longer exists.

**Cross-lens disagreement, recorded**: L1 dispositioned this site NOTED under False Alarm Filter 2
(deliberately transitional, window one `mktemp` wide, purpose stated at `:134-136`), and L5
re-verified it as "landed exactly as CA-447 prescribed". Resolved **toward filing**: two lenses
filed it, the fix is one line, and the site's own comment twelve lines below contradicts it. The
one-`mktemp` window is why this is **P2, not P1**.

**Fix**: convert all six residual sites to the canonical four-arm split, in the same pass as CA-481.

**Verification**: covered by CA-481's sweep assertion. Manually: `kill -INT` the linter during the
window and confirm exit status 130.

**Files affected**: `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/bin/tests/_harness.sh`,
`plugins/edm/bin/tests/harness-smoke.sh`, `plugins/edm/bin/tests/wave6-smoke.sh`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-lint-artifacts:134-136` and `:145-148`
(the two comments must agree with the code between them).

---

### CA-483 (P2, lenses L6 + L7 + L9 + L11 -- four-lens, highest confidence of the round): root `CLAUDE.md` still says v3.1.0

**Problem**: repository-root `CLAUDE.md:61` reads `- **edm** (v3.1.0) -- ...` while
`.claude-plugin/marketplace.json:35`, `plugins/edm/.claude-plugin/plugin.json:4` and
`plugins/edm/CHANGELOG.md:7` all say **3.2.0**. CA-431's sweep covered three of four sites. This is
a **repeat of CA-127**, which filed and fixed this exact row at round 3 (then stuck at `v2.1.0`) and
left nothing behind to keep it in step, so it re-staled on the very next bump -- the clearest single
instance in the ledger of why CA-416's enforcement half matters. It is a **specified deliverable**:
T21 AC2 (`epics/03:237-243`) makes the root Current Plugins entry an EDMV3 deliverable and verifies
it by grep, while T66 AC1's CA-431 amendment (`epics/11:648-654`) covers only the two manifests. The
skill inventory on the same line is still accurate (14 commands vs 14 on-disk `SKILL.md` files).

**Fix**: set the row to `v3.2.0`; **and**, because this is the second occurrence with nothing
pinning it, add a `wave7-smoke.sh` case asserting the version token in root `CLAUDE.md`'s edm bullet
equals the version `jq` reads from `marketplace.json`'s edm plugin entry, in the same computed-count
shape CA-460's fix uses; **and** extend T66 AC1 to name the third site.

**Verification**: the new case fails when either side is bumped alone (positive control: bump
`marketplace.json` only).

**Files affected**: `CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md`.

**Spec/AC text to sweep in the same commit**: T21 AC2 and T66 AC1.

---

### CA-484 (P2, lenses L6 + L11): `score-artifacts.sh:4` says five dimensions, its own help says six

**Problem**: the file-header comment at `:4` says the scorer produces "a scores.json with exactly
five dimensions", while `:22`, `:38-41` and `DIM_NAMES` at `:145` all say six. Line 4 sits
**outside** the `EDM-HELP-BEGIN` sentinel that opens at `:8`, which is exactly why the CA-462 sweep
of the help text missed it -- the sweep was scoped to the sentinel block, making the miss structural.

**Fix**: drop the count from `:4` entirely and let `:38` own it (safer than restating six, since
`:38` already carries the history).

**Verification**: `grep -n 'exactly five' plugins/edm/evals/score-artifacts.sh` returns nothing.

**Files affected**: `plugins/edm/evals/score-artifacts.sh`.

**Spec/AC text to sweep in the same commit**: land with **CA-475**.

---

### CA-485 (P2, lens L6): two unswept CA-463 siblings still say "directory-size ceiling"

**Problem**: CA-463 corrected `evals/fixtures/tiny-svc/README.md:38-46` to the shipped mechanism
(git-tracked byte sum, `runs/` excluded -- re-verified correct against `.gitlab-ci.yml:356-374`) and
left two sites asserting the retired claim: **(a)** `.gitlab-ci.yml:353-355`, the comment *directly
above the code that implements it*, still says "a documented 100KB **directory-size** ceiling" and
cites the tiny-svc README, which now says the opposite; **(b)** `plugins/edm/CLAUDE.md:1020`'s
`lint:file-type-ban` row repeats it. This reproduces exactly the failure CA-463 described: a
contributor measuring directory size locally after an eval run counts untracked `evals/runs/`
output, gets a number far over 100KB, and concludes they breached a budget that is not breached.

**Fix**: replace at both sites with CA-463's standardised wording -- "100KB tracked-bytes budget
(git-tracked files only; untracked eval output under `evals/runs/` is excluded)".

**Verification**: `grep -rn 'directory-size ceiling' . ` returns nothing.

**Files affected**: `.gitlab-ci.yml`, `plugins/edm/CLAUDE.md`.

**Spec/AC text to sweep in the same commit**: any T-ticket AC naming the evals budget by mechanism.

---

### CA-486 (P2, lens L6): the `lint:shellcheck` CI-table row omits `*.awk`

**Problem**: `plugins/edm/CLAUDE.md:1021` says the job runs shellcheck over `bin/*`,
`bin/tests/*.sh` and `evals/*.sh` "(excluding `*.txt`)". The shipped job excludes **both**
extensions (`.gitlab-ci.yml:244-250`, `*.awk|*.txt) continue ;;`, with a G24/CA-233 comment
explaining that `edm-mermaid-rules.awk` is plain awk source). The sibling `lint:bash-syntax` row at
`:1015` states both correctly, which makes this a miss rather than a convention. A reader concludes
`bin/edm-mermaid-rules.awk` is shellchecked as bash.

**Fix**: change to "(excluding `*.awk` and `*.txt`)".

**Verification**: covered by CA-502's extended three-way consistency assertion.

**Files affected**: `plugins/edm/CLAUDE.md`.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-487 (P2, lens L6): the CA-407 durability note names the wrong file and the wrong grep

**Problem**: `plugins/edm/CLAUDE.md:883`'s G25/CA-342 note says "`wave6-smoke.sh` carries a computed
assertion (grep -c the real `schema_at_least(` call sites ...)". Two errors survive CA-407's fix
(whose *own* defect -- the "or comments" overclaim -- **is** closed, hence CA-407 is recorded fixed
and this is a new ID per the CA-434/CA-435/CA-438 precedent). **(1) Wrong file**: `wave6-smoke.sh`
contains exactly one occurrence of `schema_at_least`, at `:2492`, and it is prose inside a comment;
the real assertion is at **`wave7-smoke.sh:4441-4456`**. A contributor sent to `wave6-smoke.sh` to
update the pin will not find it. **(2) Wrong grep**: `schema_at_least(` matches the definition at
`bin/edm-state:1497` plus four comment mentions -- five hits, no call sites -- while the six real
call sites contain no literal `(` and the shipped assertion uses `schema_at_least "`. The
substantive counts the paragraph states are **correct** (six call sites, five canonical comment
lines; the two without are `cmd_approve_gate`'s precheck and `cmd_audit_converged`).

**Fix**: change `wave6-smoke.sh` to `wave7-smoke.sh` and quote the pattern the assertion actually
uses; or drop the parenthetical and cite the case by its shipped label, which is the durable shape
CA-368's verbatim-label rule already prescribes.

**Verification**: `grep -n 'wave6-smoke.sh' plugins/edm/CLAUDE.md` shows no G25/CA-342 reference.

**Files affected**: `plugins/edm/CLAUDE.md`.

**Spec/AC text to sweep in the same commit**: n/a (this **is** the spec text).

---

### CA-488 (P2, lens L6): `README.md:205` misclassifies `decisions.md` as optional

**Problem**: the README lists `decisions.md` among "optional on-demand files" alongside
`ROLLBACK.md`, `exec-report.md` and `post-deploy/`, but `plugins/edm/CLAUDE.md`'s layout block
annotates it **`(Must/always-present)`**, and it is load-bearing at runtime --
`skills/code-audit/SKILL.md:204-209` requires every convergence approval be appended to it, and D15
requires scope changes recorded there. Not a simplification: the other three items in the same
parenthetical are correctly classified, and README is what a new adopter reads *before* CLAUDE.md.

**Fix**: split the parenthetical -- name always-present files the summary omits
(`architecture.md`, `explorers/`, `decisions.md`) separately from the optional on-demand files.

**Verification**: manual read against `plugins/edm/CLAUDE.md`'s layout block.

**Files affected**: `plugins/edm/README.md`.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-489 (P2, lens L6): the documented pending-count command does not produce a count

**Problem**: `docs/audit-patterns/README.md:48` states the pending count is always
`grep -c 'status: pending-review' docs/audit-patterns/*.md`. Against a multi-file glob, `grep -c`
prints one `<file>:<count>` line **per file** (five library documents), not a total; and if only one
file matched, the bare number **under-reports**. The suite's own correct usage at
`wave7-smoke.sh:3805` runs it against a *single* file, which is why nothing catches this. Same
bare-`grep -c` class as CA-392 / commit `dfa71d3`.

**Fix**: state a command that totals -- `grep -o 'status: pending-review' docs/audit-patterns/*.md | wc -l`
-- and update the verbatim string assertion at `wave7-smoke.sh:3474` in the same change.

**Verification**: run both forms against the tree and confirm the new one returns a single integer
equal to the sum.

**Files affected**: `plugins/edm/docs/audit-patterns/README.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `wave7-smoke.sh:3474`'s pinned sentence.

---

### CA-490 (P2, lens L2): CA-452's core symptom survives -- the `complete:false` handshake is unreachable

**Problem**: CA-452's **CI rewiring half landed and is correct** (`.gitlab-ci.yml:738-746` no longer
aborts on run-eval exit 4; `score-artifacts.sh` re-derives `complete:false` from `run.json` at
`:644`/`:657`; `:769-775` guarantees a partial run fails the job). But the defect CA-452 was filed
for is still live: `bin/edm-compare-eval` tests for the committed baseline **first** --
`[ ! -f "$BASELINE" ] ... exit 3` at `:58-62` -- and `plugins/edm/evals/baseline/scores.json` does
not exist anywhere in the tree (`baseline/` holds only `README.md`, whose `:3-19` records the
absence as the deliberate current state). Refusal condition 3, the `complete != "true"` check at
`:67-75` that `:22` documents as one of three named refusal conditions, sits **below** that early
return, as do conditions 1 and 2. So on the partial path the sole automated caller
(`.gitlab-ci.yml:762`, one-argument form) prints `eval comparison: NOT ARMED` and exits at `:765`;
**the handshake never executes**. Two remediation comments now assert an outcome that cannot occur:
`.gitlab-ci.yml:736-737` and `plugins/edm/CLAUDE.md:1029`.

**Cross-lens resolution**: L6 N10 cleared the `CLAUDE.md:1029` wording under Filter 1 ("the
mechanism is approximated but the operator-visible outcome is exactly as documented"). **Overturned
here**: L2 establishes the outcome is *unreachable*, not merely differently mechanised.

**Fix** -- one small reorder: condition 3 reads only `$CANDIDATE` and needs nothing from the
baseline, so move `edm-compare-eval:64` (candidate JSON validation) and `:67-75` (condition 3)
**above** the baseline-existence check at `:58-62`. The handshake then fires today, on an un-armed
tripwire -- exactly the state CI is in and will stay in until the live baseline capture happens --
while `exit 3` keeps its meaning for a candidate that is complete but has nothing to compare
against. This also un-blocks conditions 1 and 2, which CA-462's `SCORER_VERSION` bump to `1.1.0`
makes newly relevant. If the reorder is rejected, **both comments must be qualified** ("once a
baseline is committed").

**Verification**: `bash plugins/edm/bin/edm-compare-eval <a-partial-scores.json>` exits **2** with
the `complete:false` refusal named, on a tree with no committed baseline. Add a `wave7-smoke.sh`
case pinning that exit code and message.

**Files affected**: `plugins/edm/bin/edm-compare-eval`, `.gitlab-ci.yml`, `plugins/edm/CLAUDE.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `.gitlab-ci.yml:736-737`, `plugins/edm/CLAUDE.md:1029`,
`bin/edm-compare-eval:22`'s three-refusal-condition docstring, and `evals/run-eval.sh:134-138`'s
`write_partial_artifacts` docstring (stale since CA-452 chose the wiring fix -- L2-N02).

---

### CA-491 (P2, lenses L4 + L1): CA-441's `Task` rule shipped with no must-fail case

**Problem**: `bin/edm-check-grants:506-517` gained a second positive rule this batch. The
established must-fail shape sits 130 lines above at `t03_ac6_case` (`wave7-smoke.sh:364-396`) --
copy the tree to scratch, strip the grant, assert exit 1 plus the file and class name (`:388-391`)
-- and it exercises the **AskUserQuestion** rule only. Because CA-441's fix granted `Task` to all
twelve skills that need it, `needs_task=1 && ! has_tool "$allowed" "Task"` at `:515` is false
everywhere and `mark_and_maybe_report` is **never reached** on the live tree, so the family of
"exits 0" assertions (`:339`, `:2860`, `:3034`, `:3171`) passes identically whether the rule works
or does not exist. A mis-escaped regex at `:509` or a `has_tool` prefix bug would leave the rule
silently protecting nothing, permanently. The `^Agent: edm-` alternative is currently carried
entirely by the first alternative; no control proves it can match at all. **Two known limits**
folded in from L1 so the new test covers them: `:511` derives `task_ln` from a whole-file grep while
the trigger is derived from the body (so a reported line can fall in frontmatter -- byte-identical
to the pre-existing `AskUserQuestion` rule at `:492-494`, hence a shared quirk, not a new defect);
and `:509` requires `spawn` and `edm-` on **one line**, so a multi-line spawn instruction escapes
the rule (no live instance: `metrics` and `verify-runtime`, the only two `Task`-less skills, contain
no spawn instruction).

**Fix**: clone `t03_ac6_case` for the `Task` rule -- strip `, Task` from a scratch
`skills/test/SKILL.md`, assert exit 1 and the reported class -- plus one synthetic control line
per regex alternative, each failing by alternative name.

**Verification**: mis-escape `:509` by hand and confirm the new case fails; revert and confirm green.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh` (and `bin/edm-check-grants` only if the
line-attribution quirk is fixed for both rules together).

**Spec/AC text to sweep in the same commit**: T03 AC6 already states the generic contract (L9
cleared it) -- no amendment needed, but the new case label must be cited verbatim if any AC names it.

---

### CA-492 (P2, lens L4): the CA-426 fixture positively pins zero-round convergence with no boundary case

**Problem**: `wave6-smoke.sh:800-815` -- `PDEBT6` is `init`-ed and given a ledger, then
`approve-gate PDEBT6 code-audit --accept-p2-debt` runs with **no** `audit-round-start` and **no**
`audit-round-complete` at all. `cmd_audit_converged`'s zero-rounds arm warns on stderr and
*proceeds*, so stdout carries the `not converged: ` prefix, the override engages, `:812` asserts
exit 0 and `:814-815` asserts the success message. **The suite now positively certifies that an
initiative which has never run a code-audit round can be converged.** The defect is the asymmetry:
CA-425's negative set added in the same batch covers a partial round (`:774`), an invalid ledger
(`:786`), the wrong gate (`:792`) and an unrecognized argument (`:795`) but has **no zero-round
member**, even though zero-round is the one class the CA-426 fix deliberately re-enabled; the
narrowing comment at `edm-state:2236` enumerates three refusal classes and silently omits the arm
that proceeds; and CA-471 landed in the same batch specifically to make round completeness
verifiable. Whether zero-round convergence is *intended* is an L9/spec question this finding does
not decide -- what L4 owns is that the behaviour is locked in by a passing assertion with no
companion case stating the boundary either way.

**Fix**: rebuild the CA-426 stream-separation regression on a fixture with a **real completed
round** plus an independently-induced stderr warn, so it no longer depends on the zero-round shape;
then add an explicit zero-round case asserting whichever behaviour is decided, with a comment naming
the decision and its authorizing artifact (a `decisions.md` entry or a T51/T68 AC).

**Verification**: the rebuilt regression still catches a reintroduced `2>&1` on
`conv_out="$(cmd_audit_converged ...)"`; the new zero-round case fails if the arm's behaviour flips.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`, `plugins/edm/bin/edm-state` (comment at
`:2236`), `SRD/edm/EDMV3__prompt-streamline/decisions.md`.

**Spec/AC text to sweep in the same commit**: `bin/edm-state:2236`'s narrowing comment must
enumerate the proceed arm; T68's ACs if the decision changes the flag's contract.

---

### CA-493 (P2, lens L4): `test:state-validate` is blocking and prints `OK` after validating nothing

**Problem**: `.gitlab-ci.yml:508-550` runs under `set -u` only (`:516`, deliberately POSIX-sh-safe,
no `-e`) and `edm-state list --paths > "$LIST_FILE"` at `:524` has its **exit status discarded**. If
enumeration fails or returns nothing -- a broken `EDM_SRD_ROOT`, a relocated `SRD/` tree, a
`jq`/layout regression in `list --paths` -- the `while` body never executes, `COUNT` stays 0, `FAIL`
stays 0, and the job prints `state-validate: 0 initiative(s) checked` (`:545`) then
`test:state-validate: OK` (`:550`) and exits 0. A **blocking** gate reports green having checked
zero initiatives, and the printed count is the operator's only signal with nothing asserting it.
This plugin already closed the identical class one directory over: CA-016 added the
`_MIN_SUITE_COUNT` floor plus the missing-preferred-suite check to `bin/tests/run-all.sh:70-91`,
whose own comment states "a zero-suite guard above catches total deletion, but does nothing if a
named suite is deleted". No equivalent exists here.

**Fix**: capture and check `edm-state list --paths`'s status on the same statement, and fail the job
when `COUNT` is 0 (or below a small committed floor), naming **enumeration** as the cause rather
than printing `OK`.

**Verification**: run the job body with `EDM_SRD_ROOT=/nonexistent` and confirm it exits non-zero
with a message naming enumeration.

**Files affected**: `.gitlab-ci.yml`.

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md`'s `test:state-validate`
CI-table row (it must state the floor).

---

### CA-494 (P2, lens L4): CA-443's fix closed one cause, not the class -- `eval:nightly` still skips silently

**Problem**: `.gitlab-ci.yml:747-753` (scoring) and `:758-768` (comparison) are both
`if [ -n "$RUN_DIR" ] ... ; fi` with **no `else` arm**, and `RUN_DIR` is re-derived independently at
`:749` and `:759` from `ls -td .../runs/*/ 2>/dev/null | head -1`. CA-443 named this exact
downstream consequence ("scoring and the baseline comparison are skipped with no message, and
eval:nightly reports success having evaluated nothing") and its remediation went entirely into
`run-eval.sh`, clamping `EDM_EVAL_KEEP_RUNS=0` to 1. Any *other* reason the directory is absent -- a
changed output root, an artifact-cleanup step, a run written outside `plugins/edm/evals/runs/` --
still yields a job that scores nothing, compares nothing, reports neither. Filed as a residual per
the CA-434/CA-435/CA-438 precedent. Held at **P2** because the job carries `allow_failure: true`.

**Fix**: derive `RUN_DIR` once, assert it non-empty and that `scores.json` exists, and give both
blocks `else echo <cause>; exit 1` arms so an unscored or uncompared run is a **named** failure.

**Verification**: run the job body with `evals/runs/` removed and confirm a named non-zero exit.

**Files affected**: `.gitlab-ci.yml`.

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md:1027`'s `eval:nightly` row.
Sequence with **CA-511**, which is the timeout reason the trailing steps can be skipped entirely.

---

### CA-495 (P2, lens L5): one smoke-suite scratch tree is never removed; eleven more sit outside the trap-covered root

**Problem**: **(a) Unconditional leak** -- `wave7-smoke.sh:7272` creates the G22b scratch tree with
`mktemp -d "${TMPDIR:-/tmp}/edm-g22b.XXXXXX"`, and a grep of the entire 8,000-plus-line suite for
`tmp_g22b` returns exactly three hits (`:7272`, `:7273`, `:7274`), **none a removal** -- no `rm`, no
trap (`:7271` clears all four dispositions), and it is not under `$TMP`, which the top-level trap at
`:25` owns. Its character-identical G22a sibling at `:7241`/`:7255` **does** have the tail `rm`, so
this is a dropped line. It leaks on the **success path** every run: `run-all.sh` discovers
`*-smoke.sh` automatically, and CI runs the aggregator twice per pipeline. macOS resolves `TMPDIR`
to a per-user `/var/folders/...` path that survives reboots. **(b) Conditional leak** -- eleven more
sites (`:5116`, `:5154`, `:5190`, `:5217`, `:5242`, `:5282`, `:5331`, `:5386`, `:5535`, `:7241`,
`:7826`) are rooted at `${TMPDIR:-/tmp}` instead of `$TMP`, inside subshells that **correctly** clear
all four inherited dispositions (`:5105-5114` explains why) and then leave a tail-position `rm -rf`
as the only cleanup. Two real abort paths: `source "$EDM_STATE"` **re-enables errexit** inside these
subshells (the suite states this at `:5163-5165`) and later statements are unguarded (`:5251`'s bare
`cat` of a stderr file that exists only if the code under test failed as expected) -- CA-450's
aggravator verbatim; and a Ctrl-C leaks these eleven while the parent trap reclaims the ~45 siblings.
The consistent-pattern filter fails cleanly: ~45 `mktemp` calls in the same file use the `$TMP`-nested
form and `wave6-smoke.sh:456-458` states the rule outright.

**Fix**: change the template root from `${TMPDIR:-/tmp}` to `${TMP}` at **all twelve** sites and keep
the `trap -` lines exactly as they are. The parent's four-signal trap then reclaims them on every
path, and the existing tail `rm -rf` calls stay valid as a fast path.

**Verification**: `grep -c 'TMPDIR:-/tmp' plugins/edm/bin/tests/wave7-smoke.sh` returns 0; run the
suite and confirm `ls "${TMPDIR:-/tmp}" | grep -c edm-` is unchanged before and after. Consider a
`bin/tests` tripwire asserting every `mktemp -d` under `bin/tests/*.sh` either interpolates `${TMP}`
or is paired with a trap -- the T61 AC11 sweep at `:1137` scans `bin/` and `evals/` only and
explicitly excludes `/tests/`.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `wave6-smoke.sh:456-458`'s stated rule (it becomes
true of the whole suite); T61 AC11's scope note if the tripwire is widened.

---

### CA-496 (P2, lenses L7 + L11): the CLI-family durability loop omits the tenth helper -- the one CA-436 added

**Problem**: `wave7-smoke.sh:5900` hardcodes nine `bin/` helpers and omits
`edm-lint-staged-artifacts`, created by CA-436's own remediation and now the delegate for the
plugin's most privileged hook. The comment at `:5924-5926` still claims "all 12 print_help call
sites in the plugin are covered"; there are **13**. The file conforms today (`:29` sources the
shared lib, `:32` uses the `${BASH_SOURCE[0]:-$0}` caller convention), so there is no live defect --
the finding is that the one property this loop exists to provide, **durability**, is exactly what
the newest and most privileged member lacks. Third instance of one shape (CA-231, CA-270, now this).
The asymmetry that makes it invisible: `lint:bash-syntax`'s CA-005 ban at `.gitlab-ci.yml:126`
**derives** its file set from the tree, so the negative rule covers the new file while the positive
assertion does not. L11 adds that the G21 `die` map at `:7978` was not extended either.

**Fix**: derive the list from `bin/edm-*` minus `_edm-*.sh` the way `.gitlab-ci.yml:106` derives its
sweep, so the eleventh helper cannot repeat this; correct `:5925`'s count to 13; extend `:7978`.

**Verification**: add a scratch `bin/edm-zzz-probe` and confirm the loop picks it up.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `wave7-smoke.sh:5924-5926`'s count sentence.

---

### CA-497 (P2, lenses L7 + L8): the only undocumented `set -uo pipefail`, where "normalizing" it disables commit lint

**Problem**: `bin/edm-lint-staged-artifacts:25` is the only `set -uo pipefail` site in the plugin
with **no rationale comment**. Nine of ten PATH-exposed `bin/` scripts use `set -euo pipefail`.
Round 8 dispositioned this divergence NOTED (L7-N01) **explicitly on the ground of "documented
rationale at each site"** -- `evals/tiering-matrix.sh:61-64`, `evals/run-eval.sh`,
`evals/score-artifacts.sh` and `bin/tests/run-all.sh:10-16` each carry a CA-074 note. That predicate
does not hold here, and the consequence is not cosmetic: at least five statements are bare
`test ... && assignment` lists that return non-zero on their **ordinary** path (`:41`, `:42`,
`:107`, `:110`, `:124`), and three command substitutions have load-bearing non-zero status (`:44`,
`:106`, `:131-132`). Adding `-e` "to match the nine siblings" makes the script exit 1 at `:41`
whenever neither `EDM_SRD_ROOT` nor `CLAUDE_PLUGIN_OPTION_SRD_ROOT` is set -- **the default case** --
and exit 1 is **non-blocking** under the hook's contract, so commit-time artifact lint would stop
enforcing silently, for everyone. Same fail-open outcome CA-410 and CA-413 were each filed for,
reachable by a one-token change that looks like a consistency improvement.

**Fix**: add the CA-074-shaped rationale comment above `:25` naming the `&&`-list dependency, the
three load-bearing substitutions and the fail-open direction.

**Verification**: `grep -B3 -n 'set -uo pipefail' plugins/edm/bin/edm-lint-staged-artifacts` shows
the rationale; the round-8 L7-N01 predicate is restored for all five sites.

**Files affected**: `plugins/edm/bin/edm-lint-staged-artifacts`.

**Spec/AC text to sweep in the same commit**: n/a (this is the missing prose).

---

### CA-498 (P2, lens L7): the `Task` rule landed without the `Skill` rule the same contract names

**Problem**: `scan_skill_tool_usage` (`bin/edm-check-grants:480-518`) now carries two positive rules
-- `AskUserQuestion` at `:502` and CA-441's `Task` at `:515` -- but not a `Skill` rule.
`plugins/edm/CLAUDE.md Sec."Skills are the source of truth for orchestration"` names **two** caller
obligations, the first being that `Skill` must appear in the caller's `allowed-tools`, with grants
explicitly not inherited -- the identical failure mode CA-441 was filed on. No live gap today (only
`skills/orchestrator/SKILL.md` instructs a `Skill` invocation and it grants `Skill`), but "no live
gap today" is precisely the argument the CA-441 remediation comment at `:474-478` **rejected** for
`Task`: "otherwise the next skill added has the same hole."

**Fix**: add a third positive rule -- a skill body instructing a `Skill`-tool invocation whose
`allowed-tools` lacks `Skill` is a `missing-skill-grant` violation -- and give it the must-fail case
CA-491 prescribes, in the same commit, so the new rule does not repeat the code-without-test shape.

**Verification**: a scratch copy of `skills/orchestrator/SKILL.md` with `Skill` stripped exits 1
naming `missing-skill-grant`.

**Files affected**: `plugins/edm/bin/edm-check-grants`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: T03 AC6 (generic contract -- confirm it covers the
third rule as it covers the second).

---

### CA-499 (P2, lens L8): the commit hook's delegate is the only hardcoded-interpreter script in the plugin

**Problem**: `bin/edm-lint-staged-artifacts:1` is `#!/bin/bash`. Every other production and eval
script -- 12 of 12 -- uses `#!/usr/bin/env bash`. The sole outlier is the brand-new file that
`hooks.json:86` routes **all** commit-time enforcement through. **(1) Fail-open** on a host with no
`/bin/bash` (NixOS, distroless/minimal containers, hardened images): `command -v` succeeds, the hook
invokes it, exec fails with status **126**, and since the hook blocks only on exit 2, 126 is
non-blocking -- the commit proceeds with enforcement off. This is the CA-186 fail-open class
re-entering through the interpreter. **(2) Split bash versions inside one check** on macOS, the
stated primary development platform (`bin/edm-state:653`): the wrapper runs under `/bin/bash` 3.2
while the `edm-lint-artifacts` it calls at `:131` runs under `env bash` 5.x.

**Fix**: change to `#!/usr/bin/env bash`; or, if pinning bash 3.2 was intended, say so in a comment
at `:1` and add the shebang form to the T61 AC11 divergence sweep at `wave7-smoke.sh:1137`.

**Verification**: `head -1 plugins/edm/bin/*` shows one uniform shebang family.

**Files affected**: `plugins/edm/bin/edm-lint-staged-artifacts` (and `wave7-smoke.sh` if pinned).

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md`'s `bin/` table row for the
script, if it states an interpreter.

---

### CA-500 (P2, lens L8): CA-448's fix made `CLAUDE_PROJECT_DIR` a one-token bypass that records itself as enforced

**Problem**: **(a)** `bin/edm-state:1056-1064` accepts `CLAUDE_PROJECT_DIR` on the **sole** test that
it is a directory, with no cross-check against the git toplevel, the initiative directory or
`SRD_ROOT`. `check_permission_rules` produces the `enforcement` tag stamped onto every gate approval
(`:2173`, `:2306`, `:2317`, `:2338`) -- the plugin's only auditable record that a human-approval
control was armed. An invocation of the form
`CLAUDE_PROJECT_DIR=/tmp/x edm-state approve-gate <PREFIX> <gate>` does two things at once: the
env-prefixed form is one of the documented shapes that does **not** match the
`Bash(edm-state approve-gate*)` literal-prefix ask matcher (README "Matcher limitation", echoed at
`edm-state:1029-1032`), so no permission prompt fires; and it points the scan at
`/tmp/x/.claude/settings.json`, which need only contain the two literal patterns to stamp the
approval `permission-ask`. **The result is a bypass that records itself as enforced** -- exactly the
direction the function's own AC6 docstring at `:1047-1051` forbids ("a false 'present'
(permission-ask) is not [harmless], since it would overstate the tier that actually enforced the
approval"). Pre-CA-448 the equivalent needed a `cd ... &&` compound; the fix reduced it to a
one-token env prefix on a **host-supplied** variable. **(b)** CA-448's second half did not land:
`PERM_RULES_MISSING` at `:1697` still names bare relative paths, so a `prose-only` tag remains
unattributable to any resolved root.

**Fix**: accept `CLAUDE_PROJECT_DIR` only when it agrees with the repository -- resolve both with
`cd ... && pwd -P` and require equality with, or containment of,
`git rev-parse --show-toplevel`; on disagreement prefer the toplevel and say so. Then name the
resolved root in the `PERM_RULES_MISSING` diagnostic.

**Verification**: land the smoke case CA-448 prescribed -- a scratch settings tree with the two
literal patterns, invoked with `CLAUDE_PROJECT_DIR` pointing outside the repo, asserting the
enforcement tag is **not** `permission-ask`.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-state:1047-1051`'s AC6 docstring;
`plugins/edm/README.md`'s "Matcher limitation" note; `plugins/edm/CLAUDE.md`'s enforcement-tier
table.

---

### CA-501 (P2, lenses L8 + L11): commit enforcement depends on an executable bit nothing asserts

**Problem**: before CA-436 the enforcement body lived inline in `hooks.json:86` and could not fail
to be present. It is now a PATH-resolved script behind
`command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0`, and `command -v` succeeds only for
an **executable** file on PATH -- so a mode-0644 file makes the guard fire and the hook exit 0,
which a `PreToolUse` hook reads as "proceed", i.e. the same signal as "commit is clean". **Nothing
verifies the precondition**: `lint:bash-syntax` (`.gitlab-ci.yml:114`) and `lint:shellcheck`
(`:252`) pass the file as an *argument*, needing no execute bit; every T67 AC8 assertion
(`wave7-smoke.sh:4708-4739`) and `:2546` `cat` the file and grep substrings, both of which hold on a
0644 file; the only `-x` test in the whole `bin/tests/` tree is `:4570`, for `bin/tests/timing.sh`;
and **no test or CI job ever executes the delegate**. Realistic: a file created by an agent's `Write`
tool, a patch applied with `git apply` on a `core.fileMode=false` checkout, or an archive export can
all land it without `+x`. The degrade-to-exit-0 idiom is the consistent project pattern across all
nine command hooks and is **not** the finding; the finding is the **unverified new dependency**.
*(The mode bit itself was not observed this round -- no lens had `Bash` -- so the claim is that
nothing pins it, not that it is currently wrong.)*

**Fix**: assert `[[ -x ]]` in the T67 AC8 block (git tracks the mode bit, so this is a real
regression guard), ideally as a loop over every non-`_`-prefixed entry in `plugins/edm/bin/`; add a
positive control copying the script to a scratch dir at mode 0644, putting that dir first on PATH
and asserting `command -v` fails; and give the delegate at least one **behavioural** case -- a
scratch repo with a staged violating artifact asserting exit 2, and a clean one asserting exit 0.

**Verification**: `chmod 644` the file locally and confirm the new assertion turns red.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: T67 AC8's text (it must name the mode-bit assertion).

---

### CA-502 (P2, lens L10): the bash-source file set is written three times and has already diverged

**Problem**: copy A is `lint:bash-syntax` (`.gitlab-ci.yml:104-124`), copy B is `lint:shellcheck`
(`:240-263`) -- the same 20-line block verbatim -- and copy C is the T61 AC10 in-suite twin
(`wave7-smoke.sh:1081-1087`), which **omits `evals/*.sh`**. So a syntax error in
`evals/run-eval.sh`, `evals/score-artifacts.sh` or `evals/tiering-matrix.sh` is caught by CI but
**not** by a local `bin/tests/run-all.sh` -- which `plugins/edm/CLAUDE.md Sec."Testing changes"`
step 5 presents as "the same command CI runs and the fastest way to catch a regression before
opening an MR". It is not the same command for this class. This enumeration has diverged and shipped
before (CA-162, round 2), and CA-233 spent four rounds resynchronising the **exclusion** arm across
the same three loops -- its assertion at `wave7-smoke.sh:1099-1115` checks only the
`*.awk|*.txt) continue ;;` string; nothing compares the `for f in ...` glob lists, while the comment
at `:1092-1096` claims "a future edit to just one of them cannot silently re-diverge the other two".

**Fix**: (a) hold the glob triple in one place -- a YAML anchor or `!reference`d snippet consumed by
both CI jobs -- and have the in-suite twin read the same list (it already reads `.gitlab-ci.yml` at
`:1100`); (b) extend the CA-233 assertion to require the three `for` lines' glob lists to be
identical, with a positive control; (c) either add `evals/*.sh` to the twin or state in its label
that it is deliberately bin-only.

**Verification**: change one job's glob list alone and confirm the extended assertion turns red.
This assertion also verifies **CA-486**.

**Files affected**: `.gitlab-ci.yml`, `plugins/edm/bin/tests/wave7-smoke.sh`,
`plugins/edm/CLAUDE.md`.

**Spec/AC text to sweep in the same commit**: `wave7-smoke.sh:1092-1096`'s intent comment;
T61 AC10's text; `plugins/edm/CLAUDE.md:1015` and `:1021` (see CA-486).

---

### CA-503 (P2, lens L10): the audit-type enum is the one enum that breaks the file's own convention

**Problem**: the `code|srd|tickets` enum is spelled out **six** times in `bin/edm-state` -- two
`case` patterns (`:4357-4360`, `:4505-4508`, byte-identical apart from the subcommand name), two
die-message literals, and two usage strings (`:4353`, `:4502`) -- plus two help-header lines
(`:39-40`). The file states the opposite rule at `:799-803`: enums live in one space-separated
constant consumed by the space-padded membership idiom "so no caller re-encodes the enum as a second
literal", and four constants follow it (`MODE_ENUM_LIST` `:804`, `LIFECYCLE_MODE_ENUM_LIST` `:805`,
`ALL_LENS_IDS` `:1528`, `SETTABLE_KEYS` `:1923`) with every consumer deriving its diagnostic from
the constant (`:827`, `:835`, `:947`, `:1970`, `:4823`, `:4845`). No divergence today -- that **is**
the finding, per the CA-343 framing. Cost of a fourth audit type: six edits, and missing the
`complete` half leaves a round that can be **opened and never closed**, surfacing only as the
informational `OPEN_AUDIT_ROUND` anomaly.

**Fix**: add `AUDIT_TYPE_ENUM_LIST="code srd tickets"` beside the other four constants, convert both
validators to the membership idiom with `${AUDIT_TYPE_ENUM_LIST// /|}` in the diagnostic, and derive
the two usage strings from it.

**Verification**: a `count_matches_strict` single-definition pin in the shape
`wave6-smoke.sh:1067-1077` already uses.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-state:39-40`'s help header;
`plugins/edm/CLAUDE.md`'s `audit-round-start`/`audit-round-complete` rows.

---

### CA-504 (P2, lens L10): CA-419's structural half landed, its divergence half did not

**Problem**: `_cmd_set_provenance_field` (`bin/edm-state:4903-4912`, wrappers at `:4914`/`:4916`)
writes the state key and returns. Its siblings `cmd_set_parent` (`:4938-4948`) and `cmd_add_related`
(`:4951`+) both validate the target exists **and** call `write_handoff_internal` (`:4947`). So four
subcommands write a cross-initiative prefix link into state and only two refresh the committed
handoff -- while `_write_handoff_body` reads **both** un-refreshed fields into the rendered artifact
(`supersedes` `:5318`, `forked_from` `:5319`). After `set-supersedes` or `set-forked-from`, the
committed cross-user resume document shows the **stale** value until some unrelated command rewrites
it. This is CA-419's own prescription verbatim -- "collapse both into one function **and bring the
pair in line with `cmd_set_parent`'s `write_handoff_internal` call in the same edit**"; CA-419's text
called the divergence "the more interesting half".

**Fix**: add `write_handoff_internal "$prefix"` as the last line of `_cmd_set_provenance_field` --
**one line**, which is precisely what the extraction was supposed to make cheap. Decide the
validation half explicitly in the same commit: either add the `state_file_for`/`-f` existence check
to match the sibling pair, or record in `plugins/edm/CLAUDE.md`'s state-field table why provenance
links may name a not-yet-created initiative.

**Verification**: `edm-state set-supersedes <A> <B>` then `grep -n 'supersedes' <init>/HANDOFF.md`
shows `B`; add a `wave6-smoke.sh` case asserting it.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/CLAUDE.md`,
`plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md`'s state-field table rows for
`supersedes`, `forked_from` and `parent_prefix` (the validation asymmetry must be stated or removed).

---

### CA-505 (P2, lens L10, medium confidence): CA-418's Coverage width is declared twice and the two disagree

**Problem**: the DRY half landed (`bin/edm-state:1116-1118` defines three shared header constants
referenced from all four sites; metrics-report's inline `printf` widths are gone). But the Coverage
column width is declared **twice**: as a jq pad ladder in the row defs (`:1097` layer 9/8/7, `:1106`
epic 8/7/6) and as a `printf` field spec in the header constants (`:1116` `%-10s`, `:1118` `%-9s`).
For an integer `pct` the row emits an **11**-column field where the header allocates 10, and a
**10**-column field where the header allocates 9 -- both off by one in the same direction, so the
trailing `Measured At` header sits one column left of its data; for the **fractional** `pct` the
state schema documents (`"pct": 82.4`), the offset widens to three columns. `COVERAGE_EPIC_HEADER`
(`:1117`) is correct because Coverage is its last column. This is L10's mandate rather than a
cosmetic nit because the extraction's own comment at `:1108-1115` asserts "Widths derive from the
row clamps" -- true of the 14/15/14 clamps, **false** of the Coverage width. That is the
CA-343/CA-420 class (a comment asserting single-sourcing over a site that is not single-sourced) at
a fourth site, introduced by the fix for the finding that named the class.

**Confidence: medium** -- derived by hand from the format strings; no lens had `Bash` this round, so
the rendered offsets were not observed. CA-418 asked the next round to confirm by running both
commands; **that request is still outstanding.**

**Fix**: emit each header from the same constants the row def pads with (or at minimum widen
`%-10s`/`%-9s` to `%-11s`/`%-10s` and add a comment naming the row def as the number's owner).

**Verification**: **run both commands first** --
`edm-state get-coverage <PFX>` and `edm-state metrics-report <PFX>` -- and confirm the header sits
over its data for both integer and fractional `pct`. Then extend `wave5-smoke.sh:111-125`, which
today compares only the **data** row byte-for-byte, to compare the header/underline pair too.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave5-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-state:1108-1115`'s "widths derive from the
row clamps" comment.

---

### CA-506 (P2, lens L11): the CA-471 downgrade is irreversible but step 9a's repair loop has no terminus

**Problem**: `round_type` has exactly two writers -- `_cmd_audit_round_start_body:4345` and the
CA-471 arm at `:4488` -- it is **not** in `SETTABLE_KEYS` so `edm-state set` refuses it, and
re-running `audit-round-complete` is refused by the once-only guard at `:4424-4425`. Yet
`skills/code-audit/SKILL.md:147-149` tells the operator to "go back to step 8a, persist the missing
halves, and record the miss in `tooling-notes.md` -- do not proceed to the convergence gate on a
downgraded round." **Persisting the halves cannot restore the round.** It is permanently
non-convergent; the only real exit is a fresh `audit-round-start` plus a full eleven-lens re-run,
and that is stated nowhere. An operator following the instruction literally repairs the artifacts,
re-reads the gate refusal, and has no documented next step. Partial credit on Filter 2:
`bin/edm-state:4443-4444` explains the downgrade's *intent*; what survives is that the **skill** --
the operative surface -- describes a repair without naming its cost or its terminus. Compounded by
**CA-479**, whose ambiguous-glob defect can trigger this irreversible downgrade **spuriously**.

**Fix**: one sentence at `SKILL.md:147-149` -- persisting the halves preserves the artifacts for the
record but does not clear the recorded downgrade; the round stays non-convergent and reaching
convergence requires a new `audit-round-start` and a fresh full round. Echo the same sentence from
the `:4468` warn text so the operator reads it when it fires.

**Verification**: a `wave7-smoke.sh` `check` on that clause so a future rewrite cannot drop it; plus
a `wave6-smoke.sh` assertion that the warn text contains the recovery sentence.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/bin/edm-state`,
`plugins/edm/bin/tests/wave6-smoke.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: the new T51 AC from **CA-510** must state the recovery
path; `plugins/edm/CLAUDE.md`'s `round_type` state-field row.

---

### CA-507 (P2, lens L11): CA-466's `tooling-notes.md` consumer is one elision from being unwired again

**Problem**: the synthesizer reads `tooling-notes.md` and carries a delivery-degradation note into
`REMEDIATION.md` -- but that instruction lives **only** in the agent definition
(`agents/edm-audit-synthesizer.md:25-26`, `:194-198`). The skill's step-9 bullet list
(`skills/code-audit/SKILL.md:123-129`) and the fenced Synthesizer Phase spawn prompt (`:345-362`)
enumerate the lens reports and the ledger and **never name the file**. CA-164's whole lesson was
that the skill is the **operative** instruction at spawn time; CA-193's remediation moved the lens
JSONL schema *inside* the fenced launch template for exactly this reason; and CA-130 records
delivered agent definitions arriving stale for seven-plus consecutive rounds -- **reproduced again
this round across all eleven lenses**, which is the strongest available evidence that the agent
definition is the wrong single home for a structural instruction. The sibling `lenses-run.txt` sits
in the same position but is protected by `wave7-smoke.sh:1507-1510`'s T24 AC0; `tooling-notes.md`
has no structural assertion at all.

**Fix**: add one line to the fenced spawn prompt at `:347-361` -- read
`${OUTPUT_DIR}/tooling-notes.md` if it exists and carry a one-line delivery-degradation note into
`REMEDIATION.md`.

**Verification**: one `wave7-smoke.sh` `check` asserting that clause is **inside the fence**,
mirroring the G13/G6 fence-body extraction at `:6930-6941`.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: T24's AC set (the fence-body assertion's owning AC).

---

### CA-508 (P2, lens L9): nine pack statistics still assert 67 tickets after T68 landed

**Problem**: EDMV3-T68 was added to the index and the EDMV3-90 boundary row, but the pack's own
bookkeeping was not swept. `tickets/README.md`: `:12` (67, `T01..T67`); `:232` (E4 = 10, wave B --
T68 is E4 wave C); `:240` (Total 67); `:257-266` (S=31, total 67, "4 + 31 + 26 + 6 = 67"; with T68
it is 32/68); `:365-384` (the `WC` Mermaid subgraph lists T45..T67 with **no T68 node and no
`T28 --> T68` edge**, while `:221` declares `Depends On | T28`); `:519-521`; `:527-531` ("All 67
nodes appear in exactly one `class` line ... = 67"); `:545` ("123 edges over 67 nodes");
`:586-588`; `:737-741`. **Separate convention conflict**: `:590-596` states a Won't Have "is not
delivered by anything", records EDMV3-90 as *stripped* from `SRD Refs`, and notes that listing one
"made the pack's own statistics table contradict its ticket field tables in five places" -- yet
`:221` and `epics/04:1200` now put `EDMV3-90 (amended)` **back** into a ticket's `SRD Refs` while
`:723-729` still reports Won't-Have-covered-by-a-ticket = **0**.

**Fix**: sweep all nine statistics to 68 / `T01..T68`; add the T68 Mermaid node, the `T28 --> T68`
edge and its `class` line; and resolve the Won't-Have convention explicitly -- either amend
`:590-596` to sanction an `(amended)` `SRD Ref` and update `:723-729`'s count, or strip EDMV3-90
from T68's `SRD Refs` and record the authorization in `Depends On`/rationale instead.

**Verification**: re-derive each stated count by grep and confirm agreement; render the Mermaid
graph and confirm T68 appears with its edge.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/README.md`,
`.../tickets/epics/04-structured-findings.md`.

**Spec/AC text to sweep in the same commit**: all nine statistics sites plus `:590-596` and
`:723-729`. Sequence with **CA-509**, the `srd.md` half of the same amendment.

---

### CA-509 (P2, lens L9): the pack asserts an SRD amendment that does not exist

**Problem**: `tickets/README.md:689` and `epics/04:1200`, `:1207` say EDMV3-90 is "amended by
D57/D58 for exactly one sanctioned flag", and T68's `SRD Refs` reads `EDMV3-90 (amended, D57/D58)`.
`srd.md` EDMV3-90 is **byte-unchanged**: AC1 (`:3836-3837`) still reads "No `--force`,
`--accept-partials`, `--skip-checks`, `--yes`, or equivalent bypass flag exists on
`phase-complete`, `archive`, `approve-gate`, or `audit-converged`", and AC4 (`:3846-3848`) still
bans a recorded-exemption category. `srd.md` is still v1.3.0 with **no CR entry** -- contrast the
pack's own amendment route, CR1-CR6 at `tickets/README.md:785-795`, each of which landed as a
versioned `srd.md` change. **Explicitly not a re-file of CA-423** (NOTED under human override D58):
no claim is made that the flag is unauthorized. The defect is the missing **paperwork half** -- D58
enumerated four consequences and `srd.md` was not among them, leaving one governing artifact
asserting a fact about another that the other contradicts, with the **SRD** being the one that is
wrong on the record.

**Fix**: land the amendment D57/D58 already authorize -- amend EDMV3-90 AC1 and AC4 to carve out the
single sanctioned flag **by name**, bump `srd.md`'s version, and add the CR entry. If the pack's
claim is withdrawn instead, strip `(amended)` from both pack sites. Do not leave the two disagreeing.

**Verification**: `grep -n 'equivalent bypass flag' SRD/edm/EDMV3__prompt-streamline/srd.md` shows
the carve-out; the CR table lists the new entry; `srd.md`'s version line is bumped.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/srd.md`,
`.../tickets/README.md`, `.../tickets/epics/04-structured-findings.md`.

**Spec/AC text to sweep in the same commit**: EDMV3-90 AC1 and AC4; the CR table; `decisions.md`
D57/D58 (add the `srd.md` consequence D58 omitted).

---

### CA-510 (P2, lens L9): CA-471's convergence-blocking refusal has no owning AC

**Problem**: the `round_type` downgrade in `cmd_audit_round_complete` (`bin/edm-state:4438-4468`)
plus the refuse-to-proceed gate at `skills/code-audit/SKILL.md:104-113` is a **convergence-blocking
refusal with no acceptance criterion**, and both candidate owners disclaim it: T27 Out of Scope
(`epics/04:445`) assigns `audit-round-complete` to T51; T51 Out of Scope (`epics/08:203`) assigns
`round_type` recording to T27; T51's AC1-AC10 (`epics/08:145-186`) cover only timestamp, duration,
tokens, cost, the `OPEN_AUDIT_ROUND` anomaly, metrics, C-4, double-completion and atomicity; and T27
AC1 (`epics/04:375-380`) derives `round_type` at `audit-round-**start**` only. The pack's own rule
at `tickets/README.md:66-68` requires any ticket adding "a gate, a refusal, an allowlist, or a
permission boundary" to carry **at least one positive and one negative AC**; this has neither.

**Fix** (L9's recommendation, adopted -- the mechanism is a genuine improvement over CA-471's own
prescription, so **do not remove it**; give it an owner): add an AC to **T51** with a positive
branch (a complete round with all lens JSONL present stays `full`), a negative branch (a
missing/empty/unparseable `lens-L{N}.jsonl` records `partial` and `audit-converged` then refuses),
a C-4 branch (no pass directory or no `lenses-run.txt` leaves the round unchanged), and the recovery
path from **CA-506**; and **delete the contradicting Out-of-Scope line in both T27 and T51** in the
same commit.

**Verification**: the new AC's `Verify:` clause must cite the **verbatim** shipped case labels added
by **CA-477**, per `tickets/README.md:73-81`.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/epics/08-*.md`,
`.../tickets/epics/04-structured-findings.md`.

**Spec/AC text to sweep in the same commit**: T51 Out of Scope; T27 Out of Scope; T27 AC1;
`tickets/README.md`'s coverage map.

---

### CA-511 (P2, lens L3): the eval's inner timeout budget is uncoupled from the outer CI job timeout

**Problem**: `eval:nightly` sets `timeout: 150m` (9000s). `run-eval.sh` runs exactly three phases
(`:500`, `:533`, `:571`), each bounded by `PHASE_TIMEOUT_SECONDS` (default 2700s), plus a 60s auth
probe (`:343`) -- **8160s = 136m before `npm install`, provisioning, scoring and comparison**, i.e.
the inner budget already consumes ~90% of the outer. Two consequences. **(1)** When the outer
timeout wins, GitLab kills the job and the trailing `script:` steps -- `score-artifacts.sh`
(`:748-753`), `edm-compare-eval` (`:758-768`) and CA-452's own "a partial run always fails the job"
step (`:771-775`) -- **never run at all**, so the partial-run contract is bypassed precisely when the
run was partial. **(2)** CA-444 validated the knob's *type* but left it **unbounded above**:
`EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600` passes validation and makes `3 x 3600 = 180m > 150m`, so the
phase timeout becomes dead wiring. Neither file references the other.

**Fix**: derive one from the other -- refuse at `run-eval.sh` startup when
`3 * PHASE_TIMEOUT_SECONDS + 120` exceeds `${CI_JOB_TIMEOUT:-}` where that variable is present --
and add a comment at `.gitlab-ci.yml:713` naming the three-phase arithmetic the 150m figure derives
from, so a future edit to either number sees the other.

**Verification**: `EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600 CI_JOB_TIMEOUT=9000 bash plugins/edm/evals/run-eval.sh --provision-only`
exits 2 naming the arithmetic. Add a `wave7-smoke.sh` case.

**Files affected**: `plugins/edm/evals/run-eval.sh`, `.gitlab-ci.yml`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `run-eval.sh:34-35`'s knob documentation;
`plugins/edm/CLAUDE.md:988-999`'s `EDM_EVAL_*` family list (which omits this knob -- L9 note 7).

---

### CA-512 (NOTED, lens L10, low confidence -- demoted, not dropped)

**Problem**: CA-472's awk-program caching wrapper exists in three copies differing only in the cache
variable name and an initialisation style (`_edm-lint-lib.sh:103-107`/`:189`,
`edm-lint-artifacts:207-208`/`:229`, `score-artifacts.sh:325-326`/`:364`), with no behavioural
divergence. Secondary, same class: the precondition the idiom depends on -- that
`$MERMAID_RULES_AWK` exists, since a failed `cat` yields a program with no function definitions and
awk aborts on an undefined-function call -- is hand-enforced twice (`edm-lint-artifacts:84`,
`score-artifacts.sh:187`) and **absent from the library that defines the path**, so the three
consumers reaching `build_line_classes` by sourcing `_edm-lint-lib.sh` carry no guard.

**Why NOTED rather than P2**: single lens at **low** confidence; the false-alarm filter is only
partly cleared (`score-artifacts.sh`'s AC6 "no `bin/` executable on PATH" constraint is not violated
by sourcing, since it already sources `_edm-cli-lib.sh` at `:133`); and the genuine friction is that
a shared helper needs a per-caller cache key while bash 3.2 has no associative arrays. Retained in
the ledger so it is not re-derived; **not** part of the convergence blocking set.

**If taken**: add `_edm_awk_with_rules <cache-varname> <main-program> <file...>` to
`_edm-lint-lib.sh`, route all three through it, and move the `[[ -f "$MERMAID_RULES_AWK" ]]`
precondition into the library beside the assignment at `:90`.

---

### Carried-forward findings (11 P2 + 2 P1) -- no new detail this round

- **CA-416 (P1)** and **CA-424 (P1)**: see the P1 table above. CA-416's `spec_swept` field shipped
  as prose in both prescribed places (`agents/edm-audit-synthesizer.md:177-182`, `:122-126`) but its
  **enforcement half did not** -- no mechanism, no smoke case, no `audit-converged` check refuses a
  wave while a `fixed` entry carries `"no"`. **This round is its measurement: 17 of 57 closures
  carry `spec_swept: "no"` and nine findings above are the direct consequence.** CA-424 is narrowed
  to the stale `T-EDMV4` label in its own `Verify:` clause (`epics/04:560`) -- the shipped labels are
  `EDMV3-T68 -- ...` at `wave6-smoke.sh:667`, `:682`, `:707`, `:713`, `:725`, and a grep for
  `T-EDMV4` under `bin/tests/` returns zero. Fix: replace the label with the verbatim shipped one.
- **CA-414 (P2, narrowed)**: the `printf`-for-`echo` half is genuinely closed at
  `edm-lint-staged-artifacts:114`, `:134`, `:138`. The `core.quotePath=false` half rests on a **false
  premise**: git suppresses quoting only for bytes above 0x80; `"`, `\` and control bytes are
  **always** C-quoted without `-z`. Such a path still fails the awk root test at `:118` (leading
  quote) or the `grep -E '^[A-Za-z0-9_-]+$'` filter at `:123`, and if it is the only staged file for
  an initiative, `prefixes` is empty, `:124` exits 0, and the initiative is unlinted with **no
  diagnostic on any channel**. Fix: `git -c core.quotePath=false diff --cached --name-only -z` read
  NUL-delimited (the `-z` is what actually disables quoting), and correct the comment at `:101-105`.
- **D60 debt set (CA-401, 402, 403, 404, 405, 453, 455, 456, 457, 459)**: documented debt, excluded
  from the convergence blocking set by decision D60. Re-verified present this round at shifted line
  numbers (L1, L4, L10). L4 notes the class **acquired new sites** in this batch
  (`wave7-smoke.sh:8167-8168`, `:8227`) -- recorded, not re-filed.

---

## Decisions / Non-Findings

These items were flagged by one or more lenses and determined **Not Actionable**. Future audits
should **not** re-investigate them.

### Standing dispositions re-confirmed (do not re-file)

1. **CA-130 -- every lens delivered without `Write` and `Bash`** (9th-10th consecutive round) -- Standing NOTED, stale-plugin-cache class; reports returned inline per the documented fallback.
2. **CA-111 -- placeholder image digests and floating `bash:3.2` tag** (L8) -- Self-declared placeholders authorized in the `.gitlab-ci.yml` header.
3. **CA-381 -- five `UserPromptExpansion` `$ARGUMENTS` hooks** (L8) -- Round 8 empirically tested both candidate fixes; both broke gate enforcement.
4. **CA-123 / CA-376 -- fd sweep** (L8) -- Re-swept: `flock`'s `200>` is still the only numeric fd in `bin/`, `evals/`, `hooks/`.
5. **CA-171 -- three untrapped `mktemp` files in `harness-smoke.sh`** (L5) -- TMPDIR-only, tiny, inline `rm -f`, assertion helpers never exit early.
6. **CA-289 -- bare `help` token accepted by 3 of 6 CLIs** (L7) -- Standing do-not-re-file; the new script lands on the majority side.
7. **CA-107 -- `.tiering_results` has zero producers** (L11) -- Standing do-not-re-file. *(Its in-code "not-in-this-batch ticket" framing is now stale since `tiering-matrix.sh` shipped -- noted, below reporting bar.)*
8. **CA-128 / CA-467 -- lens JSONL skeleton and INIT_DIR clause duplicated per agent** (L10) -- Deliberate per-context duplication; zero drift, now identity-checked.
9. **CA-283 -- `run-eval.sh`'s three copy-pasted phase blocks** (L10) -- Re-checked, still semantically equivalent; `run_phase` extraction remains right but no escalation.
10. **CA-423 -- `--accept-p2-debt` vs EDMV3-90** (L9) -- Human override D58; the flag is sanctioned. *(Only the unamended `srd.md` text is filed, as CA-509.)*
11. **CA-465(b) -- `edm-check-vocabulary`'s `SCOPE_ROOTS` names files, not the plugin root** (L9) -- Residual of a closed finding; L9 declined to re-file. Recorded so the next top-level markdown file is a known blind spot.
12. **CA-291 -- `tiering-matrix.sh:154`** -- **SUPERSEDED, not re-confirmed.** The CA-446/CA-447 convention declaration changed the premise; now filed as CA-481. Do not cite CA-291 for this site again.
13. **L6 N10 / `CLAUDE.md:1029` "stub `complete:false` is visibly refused"** -- **OVERTURNED, not cleared.** L2 shows the outcome is unreachable; folded into CA-490.

### Cleared by the False Alarm Filter this round

14. **`--accept-p2-debt` silently ignored on the `conv_ec=3` / `schema_version < 2` arm** (L1) -- Filter 1: exit 3 means no ledger, so no debt to record; documented CA-182 degradation.
15. **`edm-check-grants:511` derives `task_ln` from a whole-file grep** (L1) -- Filter 3: byte-identical to the pre-existing `AskUserQuestion` rule at `:492-494`. Folded into CA-491.
16. **`edm-check-grants:509`'s single-line spawn regex** (L1) -- No live instance; `metrics` and `verify-runtime` contain no spawn instruction. Folded into CA-491 as a known limit.
17. **`wave7-smoke.sh:4708` reuses `t67ac8_cmd` for two subjects** (L1) -- Verified correct as written; readability trap only.
18. **No unresolved `TODO`/`FIXME`/`HACK`/stub return anywhere in `bin/`, `bin/tests/`, `evals/`** (L1) -- Every hit is prose, fixture content or a detection token. Swept clean.
19. **`edm-lint-staged-artifacts:58`'s three-clause `&&`/`||` chain** (L1, L8) -- Correct for all four input combinations; case-analysed twice.
20. **`wave7-smoke.sh:262-270` CA-434 comment residue** (L2) -- Comment describes the deleted scan; below the reporting bar, fix with the next `wave7` edit.
21. **`run-eval.sh:134-138` `write_partial_artifacts` docstring stale after CA-452** (L2) -- Stub still serves a hand-run partial; only its stated reason is stale. Folded into CA-490's sweep row.
22. **`score-artifacts.sh:569-571` "pre-1.1.0 fixture shape" arm** (L2) -- The stated cause is unreachable (fixture ships with the scorer) but the branch is a legitimate corrupt-fixture guard.
23. **`edm-init:125-127` collision-guard rationale** (L2) -- Corrected in place: CA-344 removed the `command -v` guard; the guard survives on its TOCTOU leg (`:106`). Keep.
24. **`edm-lint-staged-artifacts:57` dead store** (L2) -- Zero-cost defensive initialization in new CA-436 code.
25. **`.gitlab-ci.yml:772`'s `${RUN_EVAL_EC:-0}` fallback** (L2) -- Unreachable (one generated shell per job) but a free hedge against that assumption.
26. **`_edm-lint-lib.sh:214-222` `mermaid_line_set` / `marker_line_set` have zero callers** (L2) -- Documented at `:56-65` as retained for API completeness.
27. **`edm-state:795` `gated_phase_for_gate`'s `*)` arm** (L2) -- Unreachable **by design**; CA-451 explicitly prescribed keeping it as the out-of-range contract.
28. **`edm-state:4664-4667` CA-426 comment residue** (L2) -- Incomplete rather than false (still true of `cmd_archive:3103`).
29. **`run-all.sh:145-153` byte-identical `printf` in both arms** (L2) -- Duplication only, nothing unreachable.
30. **`.gitlab-ci.yml:320-323` `COUNT`-vs-`EXPECTED_COUNT` cross-check** (L2) -- Cannot fire against the NUL extraction it accompanies, but fires under exactly the revert it guards. A working tripwire.
31. **`edm-state:3640-3641` / `:3613` CA-442 flock-vs-mkdir comment mismatch** (L3) -- Traced benign (nothing mutates state unprotected); comment correctness only.
32. **`edm-state:3123-3125` `debt_recheck_p0/p1` without `to_int`** (L3) -- Investigated and dismissed: both derive via `| length`, so non-negative integers by construction; malformed ledger short-circuits fail-safe.
33. **`edm-state:2613-2615` CA-445 residuals (newline in path, trailing space)** (L3) -- Pathological path shapes outside the fix's stated contract.
34. **`edm-state:1343`-to-`:1425` untrapped acquisition window** (L3) -- The **mechanism** behind CA-480, not an independent defect; filing both would double-count.
35. **`wave7-smoke.sh:1684` CA-467 control asserts a literal `2`** (L4) -- Both real check and control fail together; misleading message only, nothing passes wrongly.
36. **`wave7-smoke.sh:1664` `_ca467_extract` uses `head -1`** (L4) -- Latent, not live: each of the twelve files carries exactly one occurrence today.
37. **`wave7-smoke.sh:8227` CA-472 tripwire uses `\s`** (L4) -- GNU extension; on BSD grep it degrades toward a **false failure**, never a false pass.
38. **`wave6-smoke.sh:869`'s hardcoded `pass-1_2026-08-16`** (L4) -- Not a real-time dependency: `edm-state:4453` resolves by glob, so the literal never has to match the run date.
39. **CA-471 / T24 AC0 manifest fixture realism** (L4) -- Byte-compatible with the real `pass-7` `lenses-run.txt`; a representative artifact, not one shaped to suit the parser.
40. **`spec_swept` and `tooling-notes.md` landed with no smoke assertion** (L4) -- Prompt-surface-only, no executable path. *(The consumer-placement half is filed as CA-507.)*
41. **CA-425's four negative cases** (L4) -- Correct shape: `check_refuses_and_leaves_state` proves exit, message and state byte-identity from one real invocation.
42. **CA-462's `known-gap-recall` expected-value assertion** (L4) -- Hand-computed literal `33` with a skip-path companion; the CA-039 shape.
43. **`.gitlab-ci.yml:290`, `:572` bare `mktemp -d`** (L5, L8) -- Container-ephemeral, Linux-only runners; the macOS hazard motivating the `bin/`/`evals/` tripwire does not apply.
44. **Per-initiative `.gitignore` coverage** (L5) -- Re-verified complete against every runtime write into an initiative directory.
45. **Root `.gitignore:35`'s `**/*.lock`** (L5) -- Broad but harmless here; the consumer-facing copy is a **per-initiative** ignore file where it cannot reach a project-root lockfile.
46. **`_harness.sh:114`'s `local` referenced inside a trap body** (L5) -- Verified safe: the trap is installed at `:114` and torn down at `:143` while `dir` is in dynamic scope.
47. **`bin/edm-lint-staged-artifacts` creates no files** (L5) -- Newly in scope and clean: no `mktemp`, no path redirection, no `mkdir`.
48. **CA-440's hook adds no runtime-file surface** (L5) -- `qc/qc-shard-{NN}.md` is a documented tracked artifact, bounded by ticket count, overwritten not appended.
49. **`CHANGELOG.md` Unicode em dashes in release headings** (L6) -- Pre-existing house style; the plugin's own tree is scanned by no automatic invocation (documented).
50. **`plugins/edm/CLAUDE.md`'s `test:smoke` row naming `wave7-smoke.sh` literally** (L6) -- A latent second source of truth, but the statement is currently **true**; nothing to correct today.
51. **`expected.json:57` GAP-06 contains deferral vocabulary** (L6) -- `evals/` is outside `edm-check-vocabulary`'s `SCOPE_ROOTS`; covered by the CA-465(b)/CA-470 dispositions.
52. **CA-152 pricing arm-order passage; "39 subcommands"; "14 skills"; nine command hooks; three CI bans** (L6) -- All spot-verified correct against the tree.
53. **`edm-lint-staged-artifacts`'s inverted exit-code contract (2 = violation)** (L7) -- Filter 1: documented in its own header and CLAUDE.md's Hooks-behavior table; dictated by the host's PreToolUse rule that only exit 2 blocks.
54. **Mixed `[EDM]`- and script-name-prefixed diagnostics in the same file** (L7) -- Filter 3: two internally-uniform layers (hook-facing vs CLI-facing); round-8 L7-N06.
55. **POSIX `[ ]` tests where nine siblings use `[[ ]]`** (L7) -- Filters 2/3: residue of the `sh` hook string it was extracted from; harmless under its own shebang.
56. **`edm-state:3143-3148` encodes the archived layouts a third time** (L7) -- Filter 1: a destination **constructor**, not a probe; `archived_state_file_for`'s docstring scopes its claim to probes.
57. **`.gitlab-ci.yml:291`'s EXIT-only trap** (L7, L5) -- Container-ephemeral; round-8 L5-N6.
58. **`set -uo pipefail` in the three `evals/` drivers and `run-all.sh`** (L7, L8) -- Correctly dispositioned under round-8 L7-N01: each carries its CA-074 rationale. *(Only the undocumented `bin/` instance is filed, as CA-497.)*
59. **`eval:nightly` artifact retention** (L8) -- Downgraded to noted: only frozen fixture artifacts and model output are uploaded; the API key is never echoed or written, and GitLab masks the protected variable.
60. **`srd_root` normalization** (L8) -- Re-derived against eleven adversarial values; every traversal shape hits a named `exit 1`, every benign shape normalizes.
61. **Locale-dependent bracket ranges at `edm-lint-staged-artifacts:123`** (L8) -- No whitespace or glob metacharacter is a letter or digit in any locale; the SC2086 compensating argument holds.
62. **Hardcoded-path sweep** (L8) -- Zero hits for `/Users/`, `/home/`, `/opt/`, `/usr/local/`, `/var/local/` or the developer username across every executable under `plugins/edm/`.
63. **Categories not applicable this round** (L8) -- No systemd units, no init-managed daemon, no SQL, no caller-supplied-URL HTTP client, no secret written to disk; `npm install` is version-pinned with `--ignore-scripts` correctly rejected and the reason recorded in place.
64. **T68 AC case citations** (L9) -- Every cited label resolves verbatim in `wave6-smoke.sh`. False alarm cleared.
65. **CA-441's rule is not scope creep** (L9) -- T03 AC6 already states the generic contract; `Task` is an instance of an existing AC.
66. **`bin/edm-lint-staged-artifacts` is not scope creep** (L9) -- Carries the `EDM-HELP` sentinels and shared `print_help`, has a CLAUDE.md `bin/` row, and is counted by T66 AC3's mechanical derivation.
67. **T32 AC6's `git diff --stat` verify, now false** (L9) -- CA-376's D48 carve-out: the nine `git diff` forms are per-merge-request historical claims, not tree-state assertions.
68. **T02's Target Components naming `qc-summary.md`** (L9) -- `tickets/README.md:57` declares Target Components drift-tolerant by design.
69. **T21 AC4's non-exhaustive lint-stage list** (L9) -- "runs X, Y and Z"; each added job has its own owning AC.
70. **`EDM_EVAL_PHASE_TIMEOUT_SECONDS` and `EDM_STATE_LOCK_WAIT_S` absent from CLAUDE.md's enumerated families** (L9) -- Filter 2: documented at their owning components and pinned by tests. *(Folded into CA-511's sweep row.)*
71. **CA-376's `SRD_ROOT` disposition premise is now stale** (L10) -- Five byte-identical copies, and all five scripts **do** source `_edm-cli-lib.sh`, so "no shared library they could source" no longer holds. The duplication itself is **not** re-filed (five copies of a one-line env default chain); only the disposition's *reason* needs correcting.
72. **`_harness.sh`'s two shared blocks between `check_fails`/`check_refuses_and_leaves_state` and `check_state_unchanged`** (L10) -- Mechanical, not semantic; one file, no drift, `return`-vs-fall-through makes bash extraction awkward.
73. **`hooks.json`'s `Stop` and `PreCompact` byte-identical commands** (L10) -- JSON has no include mechanism; same rationale CA-376 sanctioned for the five `UserPromptExpansion` hooks.
74. **`.gitlab-ci.yml:749` / `:759` recompute `RUN_DIR`** (L10) -- Redundant, not necessary; two lines, arguably clearer per block. *(The missing `else` arms **are** filed, as CA-494.)*
75. **Pattern-library curation drains at most three entries per gate** (L11) -- Explicitly documented as carry-over ("leave the rest for the next gate"); benign again once CA-476 is fixed.
76. **`settable_consumer_scan`'s prose-mention consumer fallback** (L11) -- Explicitly carved out by CA-376 (`test_layer_skipped`'s human-facing consumer).
77. **`wave7-smoke.sh:5900`'s loop and `:7978`'s die map omit the new script** (L11 N2) -- Not a live wiring defect (the script **is** compliant with both contracts). Filed on the durability axis only, as CA-496.
78. **`bin/edm-state:1116-1118`'s three `COVERAGE_*_HEADER` constants** (L7 N11) -- Dash runs and clamps verified against the row defs; the get-coverage/metrics-report column split matches its documented row-def split. *(L10 dissents on the Coverage width only -- filed as CA-505.)*
79. **All 12 audit-lens agent frontmatter blocks; all 14 skills' model/effort; the ten-script `die()` family; job-named verdicts on both paths in all eight lint jobs** (L7 N10) -- Swept, fully consistent, no finding.

---

## Rollout Order

**Stage 1 -- P1, ship first (5 findings, parallelizable by file).** Three of the five are defects
introduced by the last remediation wave, so they carry the highest regression risk.

| Group | Findings | Files (disjoint) |
|---|---|---|
| 1a | **CA-473** | `hooks/hooks.json`, `skills/implement/SKILL.md`, `plugins/edm/CLAUDE.md` |
| 1b | **CA-474** | `.gitlab-ci.yml` |
| 1c | **CA-475** + **CA-484** (same sweep) | `evals/baseline/README.md`, `evals/score-artifacts.sh`, `epics/03`, `wave7-smoke.sh` |
| 1d | **CA-476** | `bin/edm-state`, `docs/audit-patterns/*`, `wave7-smoke.sh` |
| 1e | **CA-477** + **CA-478** (same test block) | `bin/edm-state`, `wave6-smoke.sh` |

1a-1d are file-disjoint and can run in parallel. 1c and 1e both touch a smoke suite -- sequence 1c
(wave7) before 1e (wave6) or land them in one commit. **CA-416 and CA-424** (carried P1) should land
with Stage 3, since CA-416 is a mechanism build and CA-424 is a one-label edit in the ticket pack.

**Stage 2 -- P2 batched by file, one commit per batch (24 findings).**

| Batch | Findings | Rationale |
|---|---|---|
| 2a -- CI config | CA-493, CA-494, CA-485, CA-511, CA-502, CA-486 | All `.gitlab-ci.yml` + its CLAUDE.md rows; one review |
| 2b -- trap hygiene | CA-481, CA-482 | One convention, one sweep assertion covers both |
| 2c -- commit-hook delegate | CA-497, CA-499, CA-501, CA-414 | One file plus its test coverage |
| 2d -- `edm-state` internals | CA-479, CA-480, CA-503, CA-504, CA-505, CA-500 | One file; 2d must follow 1e (both touch `cmd_audit_round_complete`'s neighbourhood) |
| 2e -- smoke-suite hygiene | CA-495, CA-491, CA-492, CA-496, CA-498 | `wave6`/`wave7` + `edm-check-grants`; land after 1e to avoid conflicts |
| 2f -- docs | CA-483, CA-487, CA-488, CA-489 | Four independent one-line-to-one-paragraph doc edits |
| 2g -- skill surface | CA-506, CA-507 | Both `skills/code-audit/SKILL.md`; one commit |
| 2h -- eval comparer | CA-490 | Small reorder plus two comment corrections |

**Stage 3 -- spec and ticket pack (5 findings + the CA-416 mechanism).** CA-508, CA-509, CA-510,
CA-424, and the `spec_swept` enforcement half of **CA-416**. Sequence **last**, because CA-510's new
T51 AC must cite the verbatim case labels Stage 1e ships, and CA-509's `srd.md` amendment should
reflect the final flag contract.

**Deferred by decision: the D60 debt set (CA-401-405, 453, 455-457, 459).** Excluded from the
convergence blocking set. **CA-512 is NOTED**, not blocking.

**Convergence note**: with 7 P1 and 45 P2 open, this round does **not** converge. Round 10 should be
a **full** round -- the `--accept-p2-debt` path is available only when P0 and P1 are both zero, which
requires Stages 1 and 3 to land first.

---

## Verification Plan

**Syntax and static checks** (run from the repository root):

```sh
bash -n plugins/edm/bin/edm-state plugins/edm/bin/edm-lint-artifacts \
        plugins/edm/bin/edm-lint-staged-artifacts plugins/edm/bin/edm-check-grants \
        plugins/edm/evals/*.sh plugins/edm/bin/tests/*.sh
shellcheck plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh   # excluding *.awk, *.txt
jq empty plugins/edm/hooks/hooks.json plugins/edm/.claude-plugin/plugin.json .claude-plugin/marketplace.json
jq -c . SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl > /dev/null   # ledger parses
sh -n <the lint:hooks-shell script body>                                          # CA-474
```

**Test suites**:

```sh
bash plugins/edm/bin/tests/run-all.sh          # full suite; baseline this round was 2182/0 (orchestrator-supplied)
bash plugins/edm/bin/tests/run-all.sh --all-lint
bash plugins/edm/bin/edm-check-grants          # must exit 0
bash plugins/edm/bin/edm-check-vocabulary
bash plugins/edm/bin/edm-sync-canonical-sections --check
bash plugins/edm/bin/edm-check-skill-sync
```

**Per-finding gates that must be added, not just run** (each is a new assertion this plan requires):

| Finding | New assertion |
|---|---|
| CA-473 | hook shard token != skill shard token, with an equal-token positive control |
| CA-474 | job body parses under `sh -n`; `COUNT` reaches 9 on `alpine:3.20` |
| CA-475 | `.dimensions \| length == 6`; no `four-dimension` literal survives anywhere |
| CA-476 | five synthetic reports yield finding titles and **not** structural headings |
| CA-477 | full round with all JSONL stays `full` after completion; absent/empty/unparseable all named |
| CA-478 | unterminated final manifest line is still checked; CRLF manifest still fires |
| CA-481/482 | cross-file trap sweep: every cleanup trap names `HUP` and exits signal-shaped |
| CA-483 | root `CLAUDE.md` version token == `marketplace.json`'s edm version |
| CA-490 | partial `scores.json` exits **2** with the `complete:false` refusal, with no baseline present |
| CA-491 | scratch skill with `Task` stripped exits 1 naming `missing-task-grant` |
| CA-493 | job fails when `edm-state list --paths` enumerates zero |
| CA-501 | `chmod 644` on the delegate turns the T67 AC8 block red |
| CA-502 | the three glob lists are byte-identical, with a positive control |
| CA-504 | `set-supersedes` leaves `HANDOFF.md` current |
| CA-505 | `get-coverage` and `metrics-report` header rows compare byte-for-byte |

**Integration / manual smoke**:

1. `plugins/edm/bin/edm-init SMOKE9` in a scratch repo; confirm `qc/` filenames are disjoint after a
   simulated two-shard wave (**CA-473**).
2. Interrupt `plugins/edm/bin/edm-lint-artifacts` with `SIGINT` during its first-stage window;
   confirm exit status 130 (**CA-482**).
3. Create a lockdir with no pidfile, back-date it, and confirm the next `edm-state set` reclaims it
   (**CA-480**).
4. Run `edm-state get-coverage` and `edm-state metrics-report` and eyeball column alignment for both
   integer and fractional `pct` -- **this is the command CA-418 asked round 9 to run and no lens
   could** (**CA-505**).
5. Render the ledger: `plugins/edm/bin/edm-state render-ledger EDMV3` and confirm 512 rows with no
   escaping damage.

**Re-audit (targeted)** -- re-run only the lenses whose findings were fixed:

- After **Stage 1**: **L1, L3, L4, L6, L9, L11**
- After **Stage 2**: **L2, L3, L4, L5, L6, L7, L8, L10, L11**
- After **Stage 3**: **L9** (plus **L4** if CA-416's enforcement mechanism ships with tests)

A targeted re-audit is a **partial** round and **cannot satisfy the convergence gate** (CA-471's
`round_type` downgrade makes this mechanical). Budget one further **full** eleven-lens round after
Stage 3 for convergence.

---

## Round metadata

- **Round type: full** (11 of 11 lenses ran) -- eligible for the convergence gate.
- **Ledger**: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`, now 512 entries.
- **Markdown ledger**: rendered separately by `edm-state render-ledger`; **not** written by this plan.
