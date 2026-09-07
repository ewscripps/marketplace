# Code Audit Remediation Plan: EDMV4 -- ECC Integration

## Post-Remediation Closure (2026-09-06)

39 P2 finding(s) accepted as documented debt; all P0/P1 findings resolved. Convergence reached
2026-09-06. The cross-round ledger at `code-audit/findings-ledger.jsonl` is the authoritative
record; `findings-ledger.md` is its deterministic render, produced by `edm-state render-ledger`.

The 39 accepted P2s remain OPEN in the ledger by design -- acceptance unblocks the gate, it does
not close findings. Their split and the reasoning behind carrying rather than fixing them is in
`code-audit/p2-triage.md`; the naming of `EDMTC` as owner of the 21 test-coverage gaps, and the
deliberate decision to leave the 18 structural findings unnamed, is decision D51 in
`decisions.md`.

Of the 96 findings resolved in this round (215 total: 96 fixed, 80 NOTED, 39 accepted as debt),
two corrected the audit's own prescriptions rather
than the code: CA-088's prescription named `with_state_lock` as the correct example to copy when
that example carried the identical defect, and CA-061 established that `EDMV4-T14` AC7 was
unsatisfiable as written -- it forbade the exact wording AC2 mandated.

The original audit snapshot is preserved below.

---

## Context

- Audit date: 2026-09-04
- Round: 1 (no prior ledger; all `CA-NNN` IDs assigned fresh this round)
- Round type: **full** -- 13 lenses ran (L1-L12, L14); L13 was declared N/A by
  `edm-state detect-conditional-lenses` and correctly produced no output. `13 run + 1 N/A = 14`.
- Audited scope: `git diff main..HEAD -- plugins/edm/` on branch `edm/edmv4-ecc-integration`
  (131 files, 12282 insertions), plus the repo-root `.claude-plugin/marketplace.json`
- SRD: `SRD/edm/EDMV4__ecc-integration/srd.md` (v1.5.0, 63 requirement IDs)
- Ticket pack: `SRD/edm/EDMV4__ecc-integration/tickets/` (README + 8 epic files, 55 tickets)
- Deployment target: local (plugin distributed through the stg-marketplace clone; see CA-002)
- Evidence beyond the lenses: `orchestrator-notes.md` in this directory, and two QC shards
  commissioned on discovery of the wave-4/wave-5 QC gap --
  `SRD/edm/EDMV4__ecc-integration/qc/qc-shard-pass-w04-01.md` and `qc-shard-pass-w05-01.md`
  (3 PASS, 1 PARTIAL, 7 FAIL; all four Definition-of-Done tickets FAILed). Findings sourced from
  those shards carry `QC-W04` / `QC-W05` in the Lens(es) column.

**This round is full and therefore eligible for the convergence gate. It must not pass it.**
5 P0 and 53 P1 findings are open, including one -- CA-001 -- in which a shipped blocking hook does
the exact opposite of the acceptance criterion that authorized it, unboundedly, with the code
comment citing the AC it contradicts and the smoke test asserting the implementation rather than
the AC. `edm-state audit-converged` will refuse on the blocking set as it stands, and it is right
to.

**Raw finding count**: 247 lens findings (3 P0, 57 P1, 100 P2, 87 NOTED) plus the two QC shards,
deduplicated to **214 ledger entries** -- 5 P0, 53 P1, 75 P2, 81 NOTED. No finding was deleted;
every demotion is recorded in "Decisions / Non-Findings" below and carries a ledger line.

**Coverage caveat -- what this round did not look at.** Recorded so a reader can tell "checked and
clean" from "never checked":

- **Delivery degradation (orchestrator-recorded).** Lens agents run at `maxTurns: 30`
  (pinned by VERIF-T09 AC3). Against this diff **every lens hit that ceiling at least once and
  required resumption**. Lenses that opened by surveying the tree produced nothing in their first
  budget; lenses that wrote findings incrementally banked them. `EDMV4-61` retuned
  `edm-implementer` to 200 and `edm-qc-auditor` to 150 against measured usage; the fourteen lens
  agents were never re-measured. Treat every lens's coverage statement as budget-bounded.
- **L1 (Logic)** had no `Bash` tool: nothing was reproduced by execution, no `git diff` was read,
  and new code was located by `EDMV4-T##` markers -- **any edit to pre-existing code carrying no
  marker was missed**. Also not read: the non-EDMV4 majority of `bin/edm-state` (~6,800 lines),
  `wave6`/`wave7-smoke.sh` in full, `_edm-lint-lib.sh`, `edm-lint-artifacts`,
  `edm-check-vocabulary`, `edm-check-verifier-sentinel`, `evals/`, 13 changed `SKILL.md` files,
  `bin/tests/fixtures/**`.
- **L4 (Test Quality)** grepped `wave3-smoke.sh`, `wave4a/4b-smoke.sh` and `wave5-smoke.sh` for its
  five defect classes but did not read them line by line.
- **L6 (Doc Accuracy)** covered operator-facing messages for the five new `bin/` binaries and
  `edm-sync-canonical-sections` but **not `edm-state`'s full message surface**, and did not sweep
  `wave6`/`wave8-smoke.sh` assertion comments exhaustively.
- **L9 (Spec Compliance)** did not check the cross-cutting "no new linter warnings" clause.
- **L10 (DRY)** had no `Bash` grant -- static read only.
- **L2** did not cross-reference the five `UserPromptExpansion` hook pairs against
  `cmd_gate_check`'s full exit-code surface, and sampled rather than swept `wave8-smoke.sh`.
- **L5** did not sweep `agents/` prose for instructed runtime-file writes at all.
- **L7** sampled rather than enumerated the `bin/tests/` and `evals/` guarded-capture sites.
- **L11** took host `PATH` injection of `plugins/edm/bin/` as given rather than verifying it. If
  that assumption is ever false, every hook silently no-ops via its own `command -v` guard and no
  finding here would surface it.
- **Nothing in this round observed a hook fire from a real host event.** Per `EDMV4-62`, neither
  `/plugin update` nor `/reload-plugins` reads the working tree, so every "this is wired" claim in
  the tree is asserted against file content, never against a running host. Six tickets are recorded
  `NOT RUNTIME-VERIFIED` (D44).

## Findings Summary

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-001 | P0 | QC-W04+L12+L1+L6+L8 | bin/edm-gateguard:252-269,343-355 | T15 AC7 inverted: every state-write failure denies instead of allowing, unboundedly |
| CA-002 | P0 | L11+L6 | .claude-plugin/marketplace.json:52-83 | The three new lens agents are absent from the `agents` array (12 listed, 15 on disk) |
| CA-003 | P0 | L8+L3 | bin/edm-stop-gate:170 | Stop gate never reads `stop_hook_active` -- the session cannot terminate |
| CA-004 | P0 | L14+L4+QC-W05 | bin/edm-bash-gate:71 | A blocking `PreToolUse Bash` hook with zero behavioural coverage |
| CA-005 | P0 | QC-W05 | wave8-smoke.sh (absent) | T50 AC1's `bin/` membership assertion does not exist |
| CA-006 | P1 | L9 | qc/qc-summary.md:169 | Waves 4-5 drained with no QC; 5 tickets still unverified |
| CA-007 | P1 | L1+L2+L11 | hooks/hooks.json:82 | `PreToolUse` matcher `git commit` is not a tool name; the lint never fires |
| CA-008 | P1 | L1+L7 | bin/edm-stop-gate:160 | `2>&1` capture swallows every hookify warn and setup error |
| CA-009 | P1 | L1+L3+L12 | bin/edm-gateguard:222,348 | `EDM_GATEGUARD_MAX_DENIALS=none` makes `0 -ge none` true; every denial disabled |
| CA-010 | P1 | L3 | hooks/hooks.json:139 | `qc-shard-impl-{NN}` has no wave component; remediation overwrites the shard |
| CA-011 | P1 | L4 | wave8-smoke.sh:3667,4502 | `check` with an empty needle passes on any stdout (2 sites) |
| CA-012 | P1 | L4 | wave8-smoke.sh:251 | `check_absent` against an invented sentinel can never fail |
| CA-013 | P1 | L4 | wave8-smoke.sh:3691,5139 | Unconditional top-level `pass` calls asserting nothing (3 sites) |
| CA-014 | P1 | L4 | wave8-smoke.sh:940 | `rc=$?` after `var=$(cmd)` under `set -e`: four assertions cannot fail |
| CA-015 | P1 | L4 | wave8-smoke.sh:444 | T17 AC5 subshell exit unreadable; pass unconditional |
| CA-016 | P1 | L4 | wave8-smoke.sh:3349 | Numeric counts through the substring `check()`: 0 satisfied by 10, 20, 100 (13 sites) |
| CA-017 | P1 | L4+QC-W05 | wave8-smoke.sh:1338 | T32 AC7 bare `grep -P`: unconditionally empty on macOS |
| CA-018 | P1 | L4 | harness-smoke.sh:78 | SIGINT cleanup case passes on normal-return cleanup |
| CA-019 | P1 | L4 | wave8-smoke.sh:3253 | Uncounted NOTE branch silently skips T40 AC8 |
| CA-020 | P1 | L5+L4 | wave8-smoke.sh:1052,1148,4976 | Three surviving `.tXX-grants.err` untracked-leak instances |
| CA-021 | P1 | L6 | CLAUDE.md:626,629 +2 | Stale 11-lens counts at four sites, including guards D1 and D2 |
| CA-022 | P1 | L6 | edm-sync-canonical-sections:15; CLAUDE.md:1257 | "Two canonical sections" claim: the generator extracts seven |
| CA-023 | P1 | L6 | CLAUDE.md:1496 | `qc_shard_threshold` documented as 20; `plugin.json` ships 6 |
| CA-024 | P1 | L6 | README.md:149 | Agents table names only the 11 pre-EDMV4 lenses |
| CA-025 | P1 | L6+L9+QC-W05 | CHANGELOG.md:9-83 | `[3.3.0]` omits three new blocking hooks and every new executable |
| CA-026 | P1 | L6 | docs/ecc-integration-analysis.md:380 | Part 4.2 presents an EDMV4-T18-fixed defect as live |
| CA-027 | P1 | L7+L3+L4 | wave8-smoke.sh:311; wave6-smoke.sh:4217 | `harness_scratch_dir` reused: 13 leaks, and a tracked-file restore disarmed |
| CA-028 | P1 | L7 | skills/code-audit/SKILL.md:369 | The skill's False Alarm Filter says "do not report"; all 14 lenses say "demote" |
| CA-029 | P1 | L8 | bin/edm-hookify:222,234 | A crafted rule filename forges a `block` verdict through the TSV record stream |
| CA-030 | P1 | L8 | bin/edm-hookify:247 | One malformed rule file aborts the jq pass and disables every other rule |
| CA-031 | P1 | L12+L3+L1 | bin/edm-hookify:216 | Empty payload degrades to `{}`: `not_contains` matches, `contains` stops enforcing |
| CA-032 | P1 | L9 | CLAUDE.md:437-447 | Turn budget parity still says all four verifiers run at `maxTurns: 50` |
| CA-033 | P1 | L11 | skills/plan/SKILL.md:8 | Step 6 runs `edm-repo-readiness` with no `Bash` grant for it |
| CA-034 | P1 | L11+L2 | skills/orchestrator/SKILL.md:123 | Step 1b.5 consumes a score produced later, by no named path |
| CA-035 | P1 | L12+L1 | bin/edm-state:1725-1728,1762 | `detect-conditional-lenses` can wrongly declare L13 N/A (two mechanisms) |
| CA-036 | P1 | L12+L7 | bin/edm-repo-readiness:144 | `_rr_validate_output` captures `rc` and discards it |
| CA-037 | P1 | L12 | bin/edm-repo-readiness:198 | A failed `get-coverage` raises the overall score |
| CA-038 | P1 | L12 | bin/edm-repo-readiness:312 | `CH_CALIBRATION_AVAILABLE` defaults true; a failure awards the points |
| CA-039 | P1 | L12 | bin/edm-bash-gate:63 | The non-empty payload guard can never fire |
| CA-040 | P1 | L12 | bin/edm-stop-gate:115 | A dying `validate` is skipped with `continue` and zero output |
| CA-041 | P1 | L14 | bin/edm-hookify:199 | Four of six documented operators are never evaluated |
| CA-042 | P1 | L14 | bin/edm-hookify:209 | The `bash` and `stop` events have no match-path coverage |
| CA-043 | P1 | L14 | bin/edm-gateguard:405; edm-stop-gate:164 | The fail-open half of the hookify wiring is unproven |
| CA-044 | P1 | L14 | bin/edm-gateguard:202 | `EDM_GATEGUARD_STATE_DIR` is never exercised as a working redirect |
| CA-045 | P1 | L14 | bin/edm-gateguard:110 | A tab-less marker silently ALLOWS, disabling Phase 6 for the session |
| CA-046 | P1 | L14 | bin/edm-repo-readiness:108 | The documented `[<PREFIX>]` argument is never passed |
| CA-047 | P1 | L14 | bin/edm-repo-readiness:243 | Test stack and Coverage posture never exercised when applicable |
| CA-048 | P1 | QC-W04 | wave7-smoke.sh:3813-3825,3888-3925 | T57 AC3: no negative fixture proves any retargeted assertion discriminates |
| CA-049 | P1 | QC-W05 | wave8-smoke.sh:5005 | T50 AC2: `T50_BASH4_RE` retyped and already drifted both ways |
| CA-050 | P1 | QC-W05 | wave8-smoke.sh:5093 | T50 AC5: the sweep excludes the file the AC names |
| CA-051 | P1 | QC-W05 | wave8-smoke.sh:5156-5160 | T51 AC1: the interpreter sweep excludes `bin/tests/` |
| CA-052 | P1 | QC-W05+L8 | wave6-smoke.sh:3501,3511 | Unguarded `perl` in the plugin's only enforcement mechanism |
| CA-053 | P1 | QC-W05+L8+L4+L14 | wave8-smoke.sh:2073 | Unpaired BSD-only `stat -f`: the T43 AC9 no-write check is vacuous on GNU |
| CA-054 | P1 | QC-W05 | wave8-smoke.sh (absent) | T51 AC8: no jq-off-`PATH` test for three of five scripts |
| CA-055 | P1 | QC-W05 | wave8-smoke.sh:5330-5338,5382 | T52 AC4: four new fixture files have no effective ASCII coverage |
| CA-056 | P1 | QC-W05+L8 | bin/edm-hookify:282,285-287 | T52 AC6: the `L)` and setup-error arms bypass the sanitizer |
| CA-057 | P1 | QC-W05 | wave8-smoke.sh:3332-3341,4584,2234 | T53 AC4: no hook guard is ever executed, only string-compared |
| CA-058 | P1 | QC-W05 | EDMV4-T53 AC7/AC8 | The two runtime Definition-of-Done checks were never performed |
| CA-059 | P2 | L6 | CLAUDE.md:1309; ecc-integration-analysis.md:364,372,1026 | Stale `file:line` citations in prose |
| CA-060 | P2 | L6 | wave7-smoke.sh:8931 | The G10/CA-340 comment claims a scope the regex does not have |
| CA-061 | P2 | QC-W04 | bin/edm-gateguard:324,328,333 | T14 AC7's clean-room claim is false and AC2 mandated the copy |
| CA-062 | P2 | L9+QC-W04 | wave7-smoke.sh:3664-3671,4675-4678 | Two `NEEDS-NEW-TICKET` comments annotate assertions that now pass |
| CA-063 | P2 | L9 | bin/edm-bash-gate:1 | A sixth new `bin/` script no ticket names as a deliverable |
| CA-064 | P2 | QC-W04 | bin/edm-gateguard:50-51 | T15 AC3's "zero filesystem reads" is imprecise and unasserted |
| CA-065 | P2 | QC-W04 | commit b697142 | The T57 follow-on defect was closed by an unticketed commit |
| CA-066 | P2 | QC-W04 | bin/edm-gateguard:394 | No assertion pins the jq-spawn count on the gated allow path |
| CA-067 | P2 | QC-W04 | EDMV4-T57 AC7 | The AC pins an absolute suite count later tickets invalidated |
| CA-068 | P2 | QC-W04 | wave8-smoke.sh:4493-4494 | T15 AC9's help-block assertion is looser than the AC |
| CA-069 | P2 | QC-W05 | wave8-smoke.sh:4793-4794 | The T28 Scope check leaves 44 characters unchecked |
| CA-070 | P2 | QC-W05+L7 | wave8-smoke.sh:4962-4965 | The extra-headings waiver comment understates its own extent |
| CA-071 | P2 | L4+QC-W05 | wave8-smoke.sh:4742,4927-4955 | T28 contract-check tags overclaim control backing; nine have none |
| CA-072 | P2 | L10+L7+QC-W05 | bin/edm-bash-gate:72 +3 | The ASCII sanitizer has five copies and no single owner |
| CA-073 | P2 | L1+L8 | bin/edm-gateguard:300 | Unquoted array split applies pathname expansion to the exempt globs |
| CA-074 | P2 | L1 | bin/edm-state:4822 | `audit-round-start` does not subtract `lenses_na` from the materialized set |
| CA-075 | P2 | L1+L3 | bin/edm-state:4611-4615 | Marker reconciliation: no recreate, and a lock-free race |
| CA-076 | P2 | L1 | bin/edm-hookify:227 | `validate()` never type-checks `enabled` nor validates `action` |
| CA-077 | P2 | L1+L7+L12 | bin/edm-gateguard:361,394 | Unguarded `jq` substitutions abort the gate outside its 0/1/2 contract |
| CA-078 | P2 | L1+L8 | bin/edm-check-grants:659 | Unquoted `ls` iteration: a space in the path passes the check vacuously |
| CA-079 | P2 | L1 | wave8-smoke.sh:5359 | The non-PCRE fallback enforces a different predicate than the PCRE branch |
| CA-080 | P2 | L1 | wave8-smoke.sh:4761 | The T28 band asserts a count, never distinctness or L1-L14 coverage |
| CA-081 | P2 | L2+L3 | bin/edm-gateguard:112 | A relative `initiative_dir` is re-resolved against the hook's own cwd |
| CA-082 | P2 | L3+L5 | bin/edm-state:5992 | Shared provenance file, fixed-name `.tmp`, lock keyed on a different file |
| CA-083 | P2 | L3 | bin/edm-gateguard:262 | `gg_mark_checked` is an unlocked read-modify-write |
| CA-084 | P2 | L3 | bin/edm-gateguard:283 | `gg_record_denial` is unlocked and the budget is keyed per project |
| CA-085 | P2 | L3 | bin/edm-gateguard:236 | `gg_fresh_lines` `rm -f`s from a separately-read mtime (TOCTOU) |
| CA-086 | P2 | L3 | bin/edm-state:99 | The Phase-6 marker is written with a truncating redirect |
| CA-087 | P2 | L3 | bin/edm-state:1520 | The mkdir lock's live-holder branch has no age cap |
| CA-088 | P2 | L3 | bin/edm-state:722 | `write_atomic` references a `local` from its EXIT trap body |
| CA-089 | P2 | L3 | bin/edm-state:4983 | The completeness check downgrades irreversibly with no re-poll |
| CA-090 | P2 | L12 | bin/edm-state:4983 | The completeness gate accepts any parseable bytes |
| CA-091 | P2 | L12 | bin/edm-state:4969 | A round with no pass directory closes silently as `round_type=full` |
| CA-092 | P2 | L3 | bin/edm-state:5388 | `record-partial-verdict`'s lock spin has no backoff or fairness |
| CA-093 | P2 | L8+L3 | bin/edm-hookify:129,213 | A NUL byte desynchronizes rule bytes from rule paths |
| CA-094 | P2 | L3 | wave8-smoke.sh:347 | T17 AC2 compares live-state observations from different times and cwds |
| CA-095 | P2 | L3 | wave8-smoke.sh:2840 | T20/T17-AC9 git-status windows span the live shared worktree |
| CA-096 | P2 | L4 | wave8-smoke.sh:4553 | The suite hard-codes this initiative's live SRD artifact paths |
| CA-097 | P2 | L4 | wave7-smoke.sh:5630 | T48 AC1's positive control is a tautology |
| CA-098 | P2 | L4 | wave8-smoke.sh:2699,3027 | `grep -c ... \|\| echo 0` yields a two-line value read as a clean zero |
| CA-099 | P2 | L4 | wave8-smoke.sh:248 | T48 AC4 asserts a generic substring and tests none of its named properties |
| CA-100 | P2 | L5 | bin/_edm-datadir-lib.sh:87 | Harvested pattern files have no gitignore coverage |
| CA-101 | P2 | L5+L8 | bin/edm-gateguard:261,282 | Predictable, untrapped, symlink-following temp files in a relocatable dir |
| CA-102 | P2 | L5 | wave7-smoke.sh:2352,4575 | Two cases run `update-patterns` into the real host data directory |
| CA-103 | P2 | L5 | bin/edm-state:6094 | The harvested delta is host-global, uncapped and unrotated |
| CA-104 | P2 | L5+L7 | wave8-smoke.sh:1009 | Five scratch dirs use a third, untrapped idiom |
| CA-105 | P2 | L5 | bin/edm-gateguard:219 | `${data}/run/` accumulates a triple per project key with no sweep |
| CA-106 | P2 | L7 | bin/edm-gateguard:48 | The only consumer on `set -euo pipefail`, uncommented |
| CA-107 | P2 | L7 | bin/edm-gateguard:69 | `--help` alias sets diverge across the hook-consumer family |
| CA-108 | P2 | L7 | bin/edm-bash-gate:48 | Two of four consumers silently ignore every positional argument |
| CA-109 | P2 | L7+L8+L10 | bin/edm-hookify:106-107; _edm-datadir-lib.sh:114-121 | Three project-root resolvers diverged; the CA-500 check is missing |
| CA-110 | P2 | L7+L10 | agents/edm-audit-security.md:19-21 | The sole lens that hard-wraps the byte-identical house boilerplate |
| CA-111 | P2 | L7 | bin/edm-gateguard:88 | The two datadir-lib consumers guard sourcing with different predicates |
| CA-112 | P2 | L7+L10 | bin/edm-repo-readiness:134 | Two hand-rolled "active initiatives" derivations that disagree |
| CA-113 | P2 | L8 | bin/edm-gateguard:405 | A rule message reaches `permissionDecisionReason` with no provenance frame |
| CA-114 | P2 | L8 | bin/edm-hookify:205 | Untrusted Oniguruma pattern with no time bound; the header claim is false |
| CA-115 | P2 | L8 | bin/edm-bash-gate:55; edm-stop-gate | No kill switch on either gate |
| CA-116 | P2 | L9 | bin/edm-gateguard:368 | The `MultiEdit` arm shipped against an unmet D26 precondition |
| CA-117 | P2 | L9 | tickets/README.md:69 | The cross-cutting Changelog AC is unassignable by construction |
| CA-118 | P2 | L10 | wave8-smoke.sh:3547 | Three byte-identical awk extractors plus a near-variant, none shared |
| CA-119 | P2 | L10 | wave8-smoke.sh:120 | Two helpers re-implement `_harness.sh`'s own extract-between |
| CA-120 | P2 | L10 | bin/edm-state:3804 | `metrics-report` reads `.lenses` inline; a legacy full round renders 0 |
| CA-121 | P2 | L10 | hooks/hooks.json:19 +4 | Five copy-pasted gate blocks; one has already diverged |
| CA-122 | P2 | L11+L2 | bin/edm-gateguard:101-103 | `file`-event rules are unreachable outside Phase 6, documented nowhere |
| CA-123 | P2 | L11 | CLAUDE.md:899-901,925-926 | The canonical Hookify section still declares the layer inert |
| CA-124 | P2 | L12 | skills/srd/SKILL.md:169 | The pattern-library seed path is never checked non-empty (4 sites) |
| CA-125 | P2 | L12 | bin/edm-check-grants:656 | A missing `canonical-sections.md` makes the check silently not run |
| CA-126 | P2 | L12 | bin/tests/timing.sh:475 | An aborting gateguard still prints `budget_status=MET` |
| CA-127 | P2 | L14 | bin/edm-gateguard:222 | `EDM_GATEGUARD_MAX_DENIALS` is never set by any test |
| CA-128 | P2 | L14 | bin/edm-repo-readiness:172 | Rubric signals only observed at this repository's current values |
| CA-129 | P2 | L14 | bin/edm-hookify:286 | `list` is invoked once with output discarded |
| CA-130 | P2 | L14 | bin/edm-gateguard:375 | Only one of `MultiEdit`'s two tolerated payload shapes is driven |
| CA-131 | P2 | L14 | bin/edm-gateguard:293 | `gg_is_exempt` is only driven with a single-entry glob value |
| CA-132 | P2 | L14 | bin/edm-stop-gate:120 | The per-prefix validate-died branch is untested |
| CA-133 | P2 | QC-W05 | SRD/edm/EDMV4__ecc-integration/ (absent) | T53 AC10: the five DoD command results are recorded nowhere |

81 further findings are recorded at `NOTED` in the ledger and listed under
"Decisions / Non-Findings" below. They are not re-investigated.

## Detailed Findings

### CA-001 (P0, QC-W04 + L12 + L1 + L6 + L8): GateGuard denies forever when session state is unwritable -- EDMV4-T15 AC7 is inverted

**Problem**: T15 AC7 requires that "every state-write failure path **allows**, with a stderr warning
naming `EDM_GATEGUARD_STATE_DIR` ... **never a deny**". The implementation does the opposite.
`gg_mark_checked` warns and `return 0`s on write failure (`bin/edm-gateguard:255-258`, `:265-268`);
control returns to `gg_maybe_deny`, which proceeds straight to `gg_record_denial` and
`emit_decision deny` (`:352-354`). There is no allow path on a state-write failure anywhere in the
file.

The wave-4 QC auditor reproduced the consequence directly -- scratch project, marker present,
`run/` at mode 555, the same path six times: `rc=2` on all six calls. **The denial budget cannot
bound it**: `gg_record_denial` writes its temp file into the same read-only `run/` (`:282-284`), so
no `.denials` file is ever created, `gg_denial_count` returns 0 forever, and the AC8 budget at
`:348` never engages. The only escape is a kill switch. This is precisely the failure mode the
ticket's own Description names: "a gate that cannot record what it has already asked would
otherwise deny the same edit forever."

Three aggravating facts, all verified:
1. The code comment cites the AC while contradicting it -- `:250-251` reads "never denies again for
   lack of a mark (AC7)".
2. **The test was written to assert the implementation rather than the AC.**
   `wave8-smoke.sh:4440-4441`'s own comment header restates AC7 correctly; the assertion four lines
   later at `:4450-4453` passes on `permissionDecision == "deny"`. `:4447` selects
   `EDM_GATEGUARD_DENY_MODE=json`, which makes a deny exit 0 -- so the AC's "asserts exit 0" clause
   is satisfied while its "never a deny" clause is inverted. No fixture anywhere asserts the allow.
3. The divergence is unrecorded in `decisions.md`, and the upstream this AC was written from does
   allow: `ECC/scripts/hooks/gateguard-fact-force.js:1176` defines `allowWithStateWarning()`,
   called at `:1220`, `:1245`, `:1269`, `:1286`.

**No lens found this.** It came from the wave-4 QC shard reading the AC against the code. Four
lenses reached adjacent facets -- L12 filed the silent-failure half at P1, L1 filed the
unbounded-denial half at P2, L8 filed the missing operator signal on `gg_record_denial` at P2, and
L6 filed the contradicting comment at P2 -- but none stated the inversion against the AC.

**Fix**:
1. `bin/edm-gateguard:255-258` and `:265-268` -- have `gg_mark_checked` `return 1` on each warn
   path instead of `return 0`. Keep the stderr warning naming `EDM_GATEGUARD_STATE_DIR`.
2. `bin/edm-gateguard:343-355` -- in `gg_maybe_deny`, test `gg_mark_checked`'s status and
   `return 0` (allow) on failure, **before** `gg_record_denial` and `emit_decision deny`.
3. `bin/edm-gateguard:283` -- mirror `gg_mark_checked`'s advisory on `gg_record_denial`'s failure
   paths: one stderr line naming `EDM_GATEGUARD_STATE_DIR` and stating that the denial budget is
   not being counted (this closes L8-015 in the same edit). Do not change the decision already
   made.
4. `bin/edm-gateguard:250-251` -- the comment is correct once the code is; leave it and let it
   describe reality.
5. `wave8-smoke.sh:4450-4458` -- invert the assertion: exit 0, **empty stdout** (no
   `hookSpecificOutput` payload), and the warning on stderr. Pair it with a control proving the
   same fixture denies when the state directory *is* writable, otherwise the new allow-assertion is
   the vacuity trap this ticket was flagged for in the other direction.

**Verification**: repeat the same path six times under a read-only `run/` and assert every call
after the first allows (exit 0, empty stdout). Today all six return `rc=2`. Then run the paired
writable-directory control and confirm it still denies.

**Files affected**: `plugins/edm/bin/edm-gateguard`, `plugins/edm/bin/tests/wave8-smoke.sh`,
`SRD/edm/EDMV4__ecc-integration/decisions.md`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC7 in
`tickets/epics/02-gateguard.md` (confirm the AC text still matches the corrected behaviour; it
does -- the code moves to the AC, not the reverse); `bin/edm-gateguard:250-251`'s AC7 docstring;
`wave8-smoke.sh:4440-4441`'s comment header; `plugins/edm/CLAUDE.md`'s
`EDM_GATEGUARD_STATE_DIR` bullet in the "`EDM_GATEGUARD_*` knob family" section; a new
`decisions.md` entry recording that the divergence existed and was closed against the AC.

---

### CA-002 (P0, L11 + L6): The three new lens agents are absent from `marketplace.json`'s `agents` array

**Problem**: `.claude-plugin/marketplace.json:52-83` lists exactly 30 agent paths for `edm`, ending
at `./agents/edm-audit-wiring.md`'s alphabetical neighbours. Thirty-three agent files ship.
Absent: `edm-audit-silent-failures.md` (L12), `edm-audit-type-design.md` (L13),
`edm-audit-behavioral-tests.md` (L14) -- exactly this initiative's scope-item-4.4 deliverable.
`./agents/edm-audit-wiring.md` (L11) *is* listed, so this is not a blanket omission of lens agents.

**Orchestrator-verified**: 12 `edm-audit-*` entries listed against 15 on disk;
`plugins/edm/.claude-plugin/plugin.json` declares no `agents` key at all; and across the whole
marketplace **`edm` is the only plugin whose listed count disagrees with its disk count**
(`release-notes` lists 3 for 3; `web-cms` lists none and ships 13; the rest ship none). Registration
is complete on the other four surfaces: `ALL_LENS_IDS` (`bin/edm-state:1673`), the lens table
(`skills/code-audit/SKILL.md:288-290`), `CLAUDE.md`'s collective treatment, and `plugin.json`'s
non-declaration.

**Severity note -- read this before disputing the P0.** L11's P0 rests on the claim that a present
`agents` array *replaces* the default `agents/` directory scan rather than adding to it (quoting
"Custom agent files (replaces default `agents/`)"). Under that semantics the three files never load,
no full 14-lens round can land 14 reports, `audit-round-complete`'s CA-471 backstop records
`round_type=partial` irreversibly, and no initiative -- including this one -- can converge or
archive. **The orchestrator could not independently confirm that mechanism**: this session runs the
cached 3.2.2 plugin, which predates all three agents, so their absence from the session toolset is
equally explained by `EDMV4-62`. `web-cms` shipping 13 agents with no `agents` field is consistent
with a default scan existing but does not settle whether declaring the field suppresses it. The
finding is retained at P0 because the inconsistency is established, the downside if the mechanism
holds is total, and **both candidate fixes are cheap enough that the severity question is moot for
remediation purposes** -- fix it and the question stops mattering.

L6 reached the same fact from the other side: `CHANGELOG.md:31-33` claims `marketplace.json` was
"updated throughout" to read 14 lenses. Its `description` and `version` were; its `agents` array was
not. That claim becomes true once this is fixed.

**Fix**: at `.claude-plugin/marketplace.json:52-83`, replace the 30-entry array with
`"agents": ["./agents/"]` so the directory is scanned and no future agent can be orphaned this way
again -- **strongly preferred**, and it makes the class structurally impossible. The minimum
acceptable alternative is adding the three missing paths in alphabetical position. Either way, add a
smoke assertion that the set of `plugins/edm/agents/*.md` files is covered by the manifest -- a
live-glob-versus-manifest set difference, the shape `wave8-smoke.sh:4753` already uses for the file
count.

**Verification**: `jq '.plugins[] | select(.name=="edm") | .agents' .claude-plugin/marketplace.json`
against `ls plugins/edm/agents/*.md | wc -l`; then re-run the audit round -- **this round's lens set
cannot be assumed complete until this is settled.**

**Files affected**: `.claude-plugin/marketplace.json`, `plugins/edm/bin/tests/wave8-smoke.sh`,
`plugins/edm/CHANGELOG.md`.

**Spec/AC text to sweep in the same commit**: `CHANGELOG.md:31-33`'s "updated throughout" claim
(true only after this fix); `plugins/edm/README.md:149`'s Agents brace list (CA-024, same commit is
natural); the `EDMV4-T33` AC that scoped the manifest edit, which named `version` and `description`
but not `agents`.

---

### CA-003 (P0, L8 + L3): `edm-stop-gate` exits 2 without ever reading `stop_hook_active`

**Problem**: `bin/edm-stop-gate:170` exits 2 to block a Stop, but the script never reads its stdin
payload at all -- so it never inspects `stop_hook_active`, the boolean Claude Code sets to `true`
precisely when a Stop hook is already blocking. Orchestrator-verified: **zero occurrences of the
string in the file.**

The non-adversarial trigger needs no attacker: an initiative carrying a routine blocking-class
anomaly (`OPEN_PARTIALS` on any ticket with an unclosed PARTIAL -- which this initiative has) makes
`edm-state validate` exit 3 on every Stop. Claude is forced to continue, tries to stop, is blocked
again, forever, until the host's 8-block backstop fires -- an unbounded token burn the operator
cannot exit without disabling the plugin. The hostile variant needs no state: a `stop`-event hookify
rule can only carry an empty `conditions` array (the `stop` event defines zero matchable fields), so
**any** `"action":"block"` stop rule is unconditional by construction, and unlike `edm-gateguard`
there is no `EDM_GATEGUARD_MAX_DENIALS`-style budget to bleed it off.

**Fix**: read the Stop payload on stdin using the same idiom `edm-bash-gate:59` already uses
(`IFS= read -r -d '' PAYLOAD || true`), parse `.stop_hook_active` with `jq -r`, and `exit 0`
unconditionally when it is `true`. Degrade to exit 0 when `jq` is absent or the payload is
unparseable, matching this gate's existing soft-exit contract. Add a per-session block budget for
the hookify stop path, mirroring `EDM_GATEGUARD_MAX_DENIALS`.

**Verification**: drive the gate twice with a fixture that produces a blocking anomaly -- first with
`stop_hook_active: false` (expect exit 2), then with `stop_hook_active: true` (expect exit 0,
silent). Add both to the T46 band. Pair with the missing-`jq` and unparseable-payload cases so the
new read cannot become a fifth silent bail-out.

**Files affected**: `plugins/edm/bin/edm-stop-gate`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `plugins/edm/CLAUDE.md`'s "Hooks behavior" `Stop`
row (add the `stop_hook_active` short-circuit to the exit-code contract it states);
`bin/edm-stop-gate`'s own `EDM-HELP` block; `EDMV4-T46`'s ACs, which do not mention the loop
breaker at all -- this is a specification gap as much as a code gap, and the AC needs the clause
added at a gate.

---

### CA-004 (P0, L14 + L4 + QC-W05): `edm-bash-gate` -- a blocking hook on the highest-privilege tool surface with zero behavioural coverage

**Problem**: no test in any suite ever executes `bin/edm-bash-gate`. `wave8-smoke.sh` touches it
only as a file: `-x` (`:4566`), the `hooks.json` guard substring (`:4584`), the bash-4 parse list
(`:5113`/`:5125`) and `edm-check-vocabulary` (`:4726`). **No payload is ever piped into it.**
Untested: the exit-2 block translation (`:71-74`), all four fail-open guards (`edm-hookify` absent
`:55`, `jq` absent `:56`, empty payload `:60`, unparseable payload `:63-64`), the `{command: ...}`
projection (`:63`) and `--help`. This is a `PreToolUse Bash` hook that can refuse **every** Bash
tool call in a session, and per D44 it has also never fired from a real hook event.

Wave-5 QC reached the same gap from the DoD side and explains why both AC scopes miss it: T53 AC3
enumerates four scripts by name and `edm-bash-gate` did not exist when the pack was written
(`EDMV4-T45` added it), and AC5 is scoped to "every exit code **this SRD** documents" while
`edm-bash-gate` appears nowhere in `srd.md` -- its exit contract lives in `CLAUDE.md:1267` and its
own `EDM-HELP` block. Both ACs are therefore PASS on their literal scopes; the finding is against
the Definition-of-Done pass itself.

L14 drove all six cases by hand and reports they behave correctly today. **This is an unprotected
surface, not a live defect** -- which is exactly why it is P0: nothing would catch the regression.

**Fix**: add a `t45_bash_gate_run` helper mirroring `t14_run` and drive six cases through the real
binary:
1. `block-rm-rf-bash.json` on a matching `rm -rf` command -- expect exit 2, matched line on stderr,
   empty stdout.
2. A non-matching command -- exit 0, silent.
3. A `warn` bash rule -- exit 0, never 2.
4. A malformed rule file (hookify exit 1) -- must not escalate to a block.
5. Empty stdin -- exit 0.
6. Unparseable stdin -- exit 0.

**Verification**: `bash plugins/edm/bin/tests/wave8-smoke.sh` and confirm six new assertions in the
T45 band; then delete the `exit 2` line from a scratch copy of `edm-bash-gate` and confirm case 1
fails, proving the new coverage discriminates.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`,
`plugins/edm/bin/tests/fixtures/hookify/` (fixture reuse).

**Spec/AC text to sweep in the same commit**: `EDMV4-T50` AC1's five-name list, `EDMV4-T52` AC4's
"the four new `bin/` scripts" assignment, and `EDMV4-T53` AC3's four-script enumeration -- all
three enumerate around `edm-bash-gate` and all three need it added (this is CA-063's fix, and the
two belong in one commit); `plugins/edm/CLAUDE.md:1267`'s `edm-bash-gate` row.

---

### CA-005 (P0, QC-W05): EDMV4-T50 AC1's `bin/` membership assertion does not exist

**Problem**: AC1 requires an assertion that recomputes `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f`
and fails naming any of `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`, `edm-stop-gate`,
`edm-repo-readiness` absent from it. **Nothing in the suite does this.** The only `-maxdepth 1` uses
are `wave8-smoke.sh:3110` and `:5727`, both over `bin/tests` for suite discovery. `T50 AC1` appears
in the file exactly once, at `:5367`, inside T52's band, as a comment citing it as precedent -- the
AC is cited but never implemented.

The ticket's own Description makes this the load-bearing criterion: the five new files are covered
by T61 AC9 *only* because they sit at the top level of `bin/`, and AC1 exists to assert that
membership rather than assume it. A new script placed in a `bin/` subdirectory silently escapes the
bash-4 construct ban with nothing to say so.

**Fix**: add the membership assertion in T50's own band of `wave8-smoke.sh`, deriving the set live
from `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f` and comparing against the five names (six, once
CA-063's enumeration fix adds `edm-bash-gate`). Do not assert a count -- assert set membership and
name any absentee.

**Verification**: run the new assertion, then move a scratch copy of one named file into
`bin/subdir/` and confirm the assertion fails naming it.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T50` AC1's own five-name list in
`tickets/epics/08-cross-cutting.md` (add `edm-bash-gate` per CA-063); the `:5367` comment citing
AC1 as precedent, which currently cites an unimplemented AC.

---

## Detailed Findings (continued)

P1 findings carry the full five-element structure. P2 findings carry Problem, Fix and Spec/AC
sweep; their verification is the suite-level procedure in `## Verification Plan` below unless a
finding states otherwise. That is a deliberate proportionality call, not an omission -- 75 P2
findings each restating "run the suite" would bury the ones that need a specific control.

### CA-006 (P1, L9): Waves 4 and 5 drained with no QC at all

**Problem**: `qc/qc-summary.md:169`'s sentinel reads `wave=03 shards=10 tickets=39`. Sixteen of 55
tickets had no QC verdict of any kind -- including all four Definition-of-Done tickets (`T50`-`T53`)
and all four mid-flight scope additions (`T54`-`T57`). Eleven tickets were merged and Phase 6 closed
with no acceptance-criteria verification. This is a recurrence of the exact class `EDMV4-61`/`T55`
AC5 exists to prevent: the post-wave shard count ran after wave 3 and was never repeated. It is an
orchestrator failure, not an agent one.

**Fix**: shards `w04-01` and `w05-01` were commissioned on discovery and have landed (3 PASS,
1 PARTIAL, 7 FAIL; their findings are CA-001, CA-005, CA-048 through CA-058 and CA-061 through
CA-071 here). **Five tickets still carry no verdict: `T11`, `T39`, `T40`, `T54`, `T55`.** Commission
a shard covering them. Separately, make the post-wave shard count a per-wave obligation rather than
a once-run step.

**Verification**: `ls SRD/edm/EDMV4__ecc-integration/qc/` shows a shard for every wave; the
`qc-summary.md` sentinel reads `tickets=55`; `edm-check-verifier-sentinel` passes on every shard.

**Files affected**: `SRD/edm/EDMV4__ecc-integration/qc/`, `qc/qc-summary.md`,
`plugins/edm/skills/implement/SKILL.md`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T55` AC5's post-wave shard-count clause -- it
must bind per wave, not once per initiative.

---

### CA-007 (P1, L1 + L2 + L11): The `git commit` PreToolUse matcher never fires

**Problem**: `hooks/hooks.json:82` registers a `PreToolUse` block whose `matcher` is the literal
`git commit`. `PreToolUse` matchers filter on **tool name**; command-string filtering is the separate
per-handler `if` field. No tool is named `git commit`, so `edm-lint-staged-artifacts` -- the plugin's
only commit-time artifact gate -- never runs. L1 settled this against the published hooks
documentation; the orchestrator verified the internal argument independently: the two sibling blocks
in the same file match on tool names (`Edit|Write|MultiEdit` and `Bash`), this one does not.
`bin/edm-repo-readiness:412-414` scores lint cleanliness as 10 of 60 rubric points on the assumption
that violations are caught at commit time.

**Corroboration correction**: L2 cited `CLAUDE.md`'s admission that em dashes "survived undetected"
in `skills/` and `agents/`. **That corroboration is invalid and is dropped.** The same passage gives
a different documented cause two lines earlier -- the hook runs prefix mode, which never reaches
those directories -- and `collect_md_files` filters to `-name '*.md'`, so `bin/` helpers are never
collected in any mode. Surviving em dashes are fully explained by reach. The finding stands on the
matcher evidence alone.

**Fix**: change `:82` to `"matcher": "Bash"` and move the command filter onto the handler --
`"if": "Bash(git commit*)"` alongside `"type": "command"` at `:84-87`. D25 already records that
co-registered `PreToolUse` blocks all run and any deny wins, so the new overlap with `edm-bash-gate`
is safe.

**Verification**: reachability is **unverified-at-runtime** and cannot be settled in this session
(`EDMV4-62`: neither `/plugin update` nor `/reload-plugins` reads the working tree). Treat it like
the six D44 tickets -- verify against host `2.1.246` once pushed and record in `decisions.md`.
Statically, assert in `wave8-smoke.sh` that every `PreToolUse` matcher in `hooks.json` is a
tool-name pattern.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s "Hooks behavior" row titled
`PreToolUse matching git commit` (the row title encodes the wrong matcher); `EDMV4-T45` AC5, which
pins `hooks.json:86` byte-identical and must be amended before the block can change;
`explorers/02-hooks-runtime.md:41,46`, which records the block as a working precedent by inspection.

---

### CA-008 (P1, L1 + L7): `edm-stop-gate` swallows every hookify warn line and setup error

**Problem**: `bin/edm-stop-gate:160` captures `edm-hookify` with `2>&1` and prints only on block, so
every `warn` match and every malformed-rule-file setup error is discarded. `edm-gateguard` and
`edm-bash-gate` let both through. A contributor whose stop rule is malformed gets no diagnostic.

**Fix**: split the streams -- capture stdout for the block-line translation, let stderr pass through
unredirected, matching `edm-bash-gate:67-73`.

**Verification**: drive the gate with (a) a matching `warn` stop rule -- warn line on stderr, exit 0;
(b) a malformed rule file -- hookify's setup line on stderr, exit 0.

**Files affected**: `plugins/edm/bin/edm-stop-gate`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s "two-tier exit contract" section, which
states a warn line goes to stderr -- currently untrue through this consumer.

---

### CA-009 (P1, L1 + L3 + L12): `EDM_GATEGUARD_MAX_DENIALS` is unvalidated and a non-numeric value disables every denial

**Problem**: `:222` reads the value with a `:-3` default only; `:348` compares it arithmetically with
no `to_int()` and no regex guard. Orchestrator-tested directly:
`EDM_GATEGUARD_MAX_DENIALS=none; [[ "0" -ge "$EDM_GATEGUARD_MAX_DENIALS" ]]` is TRUE. Bash evaluates
`none` as 0, so **the gate allows every edit while printing "denial budget reached"**.
`bin/edm-state:167` already ships `to_int()` for exactly this.

**Adjudication**: L12 filed NOTED on the grounds that a non-numeric value is a loud `unbound
variable` abort under `set -u`. That is wrong -- `set -u` fires on an *unset* variable, and a
variable set to a non-numeric string is not unset. The orchestrator adjudicated for L1's P1; L12's
NOTED framing is recorded here rather than carried as a competing ledger line.

**Fix**: validate at `:222` using `edm-state`'s `to_int()` shape -- reject anything not matching
`^[0-9]+$`, warn on stderr naming the variable, the offending value and the default, then fall back
to 3. Do not silently coerce.

**Verification**: `EDM_GATEGUARD_MAX_DENIALS=none` must warn and then deny the first touch, not allow
it. Add alongside CA-127's env-reading cases.

**Files affected**: `plugins/edm/bin/edm-gateguard`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s `EDM_GATEGUARD_MAX_DENIALS` bullet;
`EDMV4-T15` AC8 and AC12.

---

### CA-010 (P1, L3): `qc-shard-impl-{NN}` has no wave component

**Problem**: `hooks/hooks.json:139` names the per-implementer shard `qc-shard-impl-{NN}.md`.
CA-515's fix was applied only to the sibling `qc-shard-pass-w{WW}-{NN}` namespace, so a Step 5
remediation loop over the same ticket range overwrites the original wave's shard, and the
rebuild-style merge propagates the verdict loss.

**Fix**: rename to `qc-shard-impl-w{WW}-{NN}.md` at `hooks/hooks.json:139` and update the merge glob
in `skills/implement/SKILL.md`. Keep the two namespaces disjoint.

**Verification**: run two implementer waves over an overlapping ticket range in a scratch initiative
and assert two distinct shard files exist, both merged.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/skills/implement/SKILL.md`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s `SubagentStop` row, which states the
`qc-shard-impl-{NN}` convention and the CA-473/CA-515 rationale verbatim; the "Project artifact
layout" `qc/` slot.

---

### CA-011 (P1, L4): `check` with an empty expected substring passes on any stdout

**Problem**: `wave8-smoke.sh:3667` ("allow prints nothing to stdout") and `:4502` (T15 AC10 "stdout
is empty") both call `check "label" "" "$actual"`. An empty needle is a substring of every string.
Orchestrator-reproduced: these are two of the four wave8 assertions that cannot fail.

**Fix**: guard the helper first -- `check()` must `fail` immediately on an empty expected substring,
naming the label, so the shape cannot recur. Then rewrite both sites to assert emptiness directly.

**Verification**: add a scratch call with an empty needle and assert the suite reports a failure;
confirm both rewritten sites fail when fed non-empty stdout.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/bin/tests/_harness.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC10 -- the AC is correct and needs no
edit; if the guard lands in `_harness.sh`, update its helper-contract comment.

---

### CA-012 (P1, L4): `check_absent` against an invented sentinel needle can never fail

**Problem**: `wave8-smoke.sh:251` asserts the absence of a sentinel that appears nowhere by
construction, so it always passes, while its label claims a real property is absent.

**Fix**: replace the invented sentinel with the literal the label names, and add a positive control
injecting that literal into a scratch copy, asserting `check_absent` then fires.

**Verification**: the positive control is the verification -- if it does not fail on the injected
copy, the assertion still proves nothing.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: n/a -- the assertion label is the only prose and the
fix corrects it.

---

### CA-013 (P1, L4): Unconditional top-level `pass` calls assert nothing

**Problem**: `wave8-smoke.sh:3691` is a bare `pass` claiming T13 AC5's exit-code set with nothing
computed. `:5139` carries two more used as log lines. All three inflate the aggregate assertion
count with unfalsifiable claims, so the suite's headline figure overstates what was proven.

**Fix**: at `:3691` drive the three documented codes and compare, or delete the claim. At `:5139`
replace both `pass` calls with `echo` so they leave the assertion count.

**Verification**: the total drops by two, and the T13 AC5 assertion fails when a scratch copy returns
an undocumented code.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T13` AC5's exit-code taxonomy; `EDMV4-T53` AC5,
graded against this band.

---

### CA-014 (P1, L4): `rc=$?` after `var=$(cmd)` under `set -e` -- four lint assertions cannot fail

**Problem**: at `wave8-smoke.sh:940` and three sibling sites the substitution's non-zero status
aborts the suite before `rc=$?` is read. A real lint violation ends the suite with no failing
assertion. This is one instance of the eleven `set -e` aborts this initiative produced -- the reason
wave-4 QC refuses to treat a reported green figure as self-evidencing.

**Fix**: use `if ! var="$(cmd)"; then rc=$?; else rc=0; fi` at all four sites.

**Verification**: point one assertion at a fixture with a real violation and confirm a FAIL rather
than an abort.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-015 (P1, L4): T17 AC5's subshell exit code is unreadable under `set -e`

**Problem**: `wave8-smoke.sh:444` -- the subshell status cannot be read, so the `pass` is
unconditional and the AC's 90-97 exit taxonomy is unreachable by any test.

**Fix**: same shape as CA-014; capture the status through an `if !` guard and assert against the
taxonomy.

**Verification**: force each taxonomy code from a scratch fixture and confirm the assertion
distinguishes them.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T17` AC5's exit taxonomy.

---

### CA-016 (P1, L4): Numeric count assertions routed through the substring `check()` helper

**Problem**: across 13 sites from `wave8-smoke.sh:3349`, an expected count of `0` is checked with the
substring helper, so `10`, `20` and `100` satisfy it. Every zero-count claim in those bands is weaker
than it reads.

**Fix**: add `check_num` doing integer comparison and convert all 13 sites. Do not reuse `check` for
numbers.

**Verification**: feed `10` to a site expecting `0` and confirm it fails; today it passes.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/bin/tests/_harness.sh`.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-017 (P1, L4 + QC-W05): T32 AC7's non-ASCII scan uses bare `grep -P`

**Problem**: `wave8-smoke.sh:1338` runs `LC_ALL=C grep -l -P ... 2>/dev/null || true`. Wave-5 QC
verified on this host that `/usr/bin/grep` -- the macOS system grep, the plugin's primary supported
platform -- has no `-P`. The error is swallowed and the exit masked, so the result is unconditionally
empty and `:1341` passes on every macOS host regardless of content. This is the **sole nominal ASCII
coverage** for the four `fixtures/code-audit/` files CA-055 shows are covered by nothing else.

**Fix**: reuse `t52_ascii_scan` (same file, `:5347-5362`), which probes `T52_HAS_PCRE` and falls back
to a POSIX class. Reconcile CA-079's predicate divergence in the same pass.

**Verification**: inject a real non-ASCII byte assembled at runtime (`printf '\xc3\xa9'`) into a
scratch fixture and confirm the scan fires on macOS.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T32` AC7; `EDMV4-T52` AC2/AC3, whose byte-scan
coverage claim leaned on this assertion.

---

### CA-018 (P1, L4): `harness-smoke.sh`'s SIGINT cleanup case passes on normal-return cleanup

**Problem**: `harness-smoke.sh:78` swallows the `kill` failure and never asserts the child's exit
status, so the case passes when the signal never arrived and cleanup ran on normal return.
**Distinct from wave7's SIGINT case** (CA-161, NOTED): L3 established that wave7 asserts child exit
130, so a missed signal there fails loudly. `harness-smoke.sh` does not.

**Fix**: assert child exit 130 and that the `kill` succeeded, mirroring `wave7-smoke.sh:6215`.

**Verification**: run with no controlling terminal and confirm the case FAILs rather than passing.

**Files affected**: `plugins/edm/bin/tests/harness-smoke.sh`.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-019 (P1, L4): An uncounted NOTE branch silently skips T40 AC8

**Problem**: `wave8-smoke.sh:3253` prints a soft `NOTE` and returns when its precondition is unmet.
The precondition is a pinned live-initiative state path, which disappears on archive -- so AC8 stops
being checked exactly when the tree changes underneath it, with no failure and no count.

**Fix**: replace the NOTE branch with a `fail` naming the missing precondition, or build the
precondition in a scratch initiative so the assertion always runs. CA-128 shares this shape; fix
consistently.

**Verification**: remove the pinned path and confirm the suite FAILs rather than noting.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T40` AC8.

---

### CA-020 (P1, L5 + L4): Three surviving `.tXX-grants.err` untracked-leak instances

**Problem**: `wave8-smoke.sh:1052`, `:1148` and `:4976` each write a stderr capture into `SCRIPT_DIR`
(`bin/tests/`, inside the tracked tree) before a conditional and remove it after the `fi`, with no
EXIT trap. Orchestrator-verified: all three exist as described, and `git check-ignore` confirms none
of `.t26/.t27/.t28-grants.err` is ignored. **A fourth instance was found and fixed during Phase 6,
so this is a class recurrence, not a first sighting.**

**Fix**: redirect all three into the EXIT-trapped scratch directory, exactly as `wave8-smoke.sh:952`
(EDMV4-T25 AC9) already does -- that site is the reference fix for this class (CA-166).

**Verification**: `git status --porcelain` byte-identical before and after a run, and after a run
interrupted with SIGINT mid-band.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T26` AC11, `EDMV4-T27` AC10 and `EDMV4-T28`'s
capture clauses; `EDMV4-T53` AC7's scratch-tree isolation claim, which this class falsifies.

---

### CA-021 (P1, L6): Stale 11-lens counts survived the EDMV4-T31 sweep at four sites

**Problem**: `CLAUDE.md:626` (guard D1, "the 11 code-audit lenses"), `:629` (guard D2, "the 11-lens
or 2-auditor fan-out"), `agents/edm-implementer.md:31`, and `bin/edm-state:2553` (the
`--accept-p2-debt` comment's "a full eleven-lens round", against `CLAUDE.md`'s mirrored fourteen).
**`EDMV4-T31` AC (f) named the D1/D2 strings explicitly** and they were still missed.
`edm-implementer.md` was outside every T29/T31/T33 Target Components list, so no sweep could reach
it -- the same unassignable-AC mechanism as CA-117. Guard D2 currently protects a smaller fan-out
than the one that ships, and the implementer's pre-emption instruction is blind to L12, L13 and L14.

**Fix**: change all four to fourteen. Add a live assertion deriving the expected count from
`ALL_LENS_IDS` and failing on any `11[- ]lens` or "eleven lens" occurrence outside the recorded
historical exemptions (CA-174 through CA-177 and CA-180, all NOTED and all deliberate).

**Verification**: the new assertion fails when any of the four is reverted and passes with the five
NOTED historical sites in place.

**Files affected**: `plugins/edm/CLAUDE.md`, `plugins/edm/agents/edm-implementer.md`,
`plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: this finding is itself a spec sweep -- additionally
amend `EDMV4-T31`'s Target Components to include `agents/edm-implementer.md` and `bin/edm-state`,
so the sweep that missed them is recorded as having had no reach rather than having failed.

---

### CA-022 (P1, L6): The "two canonical sections" claim is stale in two places

**Problem**: `bin/edm-sync-canonical-sections:15`'s `--help` says the script extracts "the two
by-name-referenced canonical sections" and to re-run after editing "either source section";
`CLAUDE.md:1257`'s `bin/` table repeats it. **The generator extracts seven**, as `CLAUDE.md`'s own
D22 section states. An operator editing one of the other five believes it is not covered.

**Fix**: correct both to seven and name them -- better, have `--help` derive the count from the
generator's own section list at runtime so it cannot drift again.

**Verification**: assert in `wave7-smoke.sh` that the help text's count matches the generation
block's list length, both computed at test time.

**Files affected**: `plugins/edm/bin/edm-sync-canonical-sections`, `plugins/edm/CLAUDE.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s "By-name reference resolution from an
installed plugin cache (EDMV3-T41)" section, which already says seven -- confirm the two agree.

---

### CA-023 (P1, L6): `qc_shard_threshold`'s documented default is 20; the plugin ships 6

**Problem**: `CLAUDE.md:1496`'s `userConfig` reference documents default `20`; `plugin.json` ships
`6`, lowered by EDMV4 wave-1 D30. A team sizes its QC fan-out against a number three times too large.

**Fix**: change `CLAUDE.md:1496` to `6`, cite D30, and add an assertion comparing the documented
default against `plugin.json`'s live value.

**Verification**: the assertion fails if either value moves alone.

**Files affected**: `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: the D30 entry in `decisions.md`; `CHANGELOG.md` -- a
changed shipped default is user-visible and belongs in `[3.3.0]` (folds into CA-025).

---

### CA-024 (P1, L6): The README Agents table names only the 11 pre-EDMV4 lenses

**Problem**: `plugins/edm/README.md:149`'s `edm-audit-{...}` brace list omits `silent-failures`,
`type-design` and `behavioral-tests`, in the same README that advertises a 14-lens audit. Same
omission set as CA-002 on a different surface.

**Fix**: add the three names, and extend CA-002's manifest assertion to cover this list too, deriving
the expected set from `agents/edm-audit-*.md`.

**Verification**: one shared live-glob assertion covers `marketplace.json`, `README.md` and
`skills/code-audit/SKILL.md`.

**Files affected**: `plugins/edm/README.md`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T33` AC11's README clause;
`CHANGELOG.md:31-33`'s "updated throughout" claim (shared with CA-002).

---

### CA-025 (P1, L6 + L9 + QC-W05): `[3.3.0]` omits every new executable and blocking hook

**Problem**: SRD Sec.3.4 DoD item 8 requires an entry documenting the 11-to-14 lens change "and every
other user-visible change in this initiative". `CHANGELOG.md:9-83` documents three things: the lens
growth, the Mermaid budget re-derivation and the Phase 5 gate deadlock. A repo-wide grep for
`gateguard|hookify|stop-gate|repo-readiness|bash-gate` over `CHANGELOG.md` returns one hit, in an
unrelated historical EDMV3 section. **Three new blocking hooks ship in 3.3.0 undocumented** --
`edm-gateguard` (denies a first-touch edit), `edm-bash-gate` (exit 2 refuses a Bash call) and
`edm-stop-gate` (exit 2 blocks completion) -- along with the hookify rules-as-data format,
`edm-repo-readiness`, `_edm-datadir-lib.sh`, six `EDM_GATEGUARD_*` knobs, a new `edm-state`
subcommand, the Step 1b.5 dialog, the `SRD/.codemap.md` slot and the changed `qc_shard_threshold`
default. A user upgrading gets three new ways their tool calls can be blocked and no line saying so.
Root cause is the ownership hole in CA-117, not an implementer miss.

**Fix**: add `Added` subsections to the existing `[3.3.0]` entry for the hook family, the hookify
rule format, the readiness scorer and the shared library, each naming the exit contract a user can
now hit. Do not edit historical entries.

**Verification**: add an assertion that every `bin/` file added by this initiative's diff is named
somewhere in the current version's entry.

**Files affected**: `plugins/edm/CHANGELOG.md`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `srd.md` Sec.3.4 DoD item 8; `EDMV4-T53`'s Target
Components (add `CHANGELOG.md` plus an AC naming DoD item 8 -- that is CA-117's fix and belongs in
this commit).

---

### CA-026 (P1, L6): `ecc-integration-analysis.md` Part 4.2 presents a fixed defect as live

**Problem**: `docs/ecc-integration-analysis.md:380` still calls the `update-patterns` read-only skip
"the path taken every time" and says "the learning loop is a no-op", after `EDMV4-T18` added the
writable plugin-data-directory branch that fixes it. The quoted `echo` text no longer matches the
shipped message. A reader planning follow-on work re-solves a solved problem.

**Fix**: rewrite Part 4.2 to record the defect as closed by `EDMV4-T18`, naming the branch and citing
the current message text, using the document's own Part 8 self-correction protocol.

**Verification**: the quoted message matches `bin/edm-state`'s current string; no live-defect framing
survives in Part 4.2.

**Files affected**: `plugins/edm/docs/ecc-integration-analysis.md`.

**Spec/AC text to sweep in the same commit**: Part 8.2's own citation correction (CA-059, same file,
same commit); `EDMV4-T18`'s ACs, to record whether the doc update was in scope.

---

### CA-027 (P1, L7 + L3 + L4): `harness_scratch_dir`'s once-per-process contract is violated

**Problem**: the helper maintains a single global `_HARNESS_SCRATCH_DIR` and one four-arm trap set.
Two consequences, found by three lenses. (a) `wave8-smoke.sh:311` plus 13 further call sites: each
call destroys the previous trap set, so 13 scratch trees leak per run and `T05_TMP`'s own traps are
voided -- `T05_TMP` has no explicit `rm`, so it leaks every run. (b) `wave6-smoke.sh:4217`, worse:
the call replaces wave6's four-arm `cleanup_wave6` traps **800 lines before** the T41 block that
mutates the tracked file `docs/canonical-sections.md`, disarming the restore that block depends on.

**Fix**: make `harness_scratch_dir` support multiple live scratch dirs -- push each onto an array,
one trap removes all -- or stop reusing it and give each site its own four-arm trap. The wave6 site
is the urgent half: it must not disarm `cleanup_wave6`.

**Verification**: `git status --porcelain` byte-identical before and after `run-all.sh`; count
`${TMPDIR}` entries before and after and assert no growth; SIGINT the suite mid-wave6-T41 and confirm
`docs/canonical-sections.md` is restored.

**Files affected**: `plugins/edm/bin/tests/_harness.sh`, `plugins/edm/bin/tests/wave8-smoke.sh`,
`plugins/edm/bin/tests/wave6-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `_harness.sh:72-84`'s once-per-process contract comment
-- it must describe the new behaviour; `EDMV4-T53` AC7's scratch-tree isolation clause.

---

### CA-028 (P1, L7): The code-audit skill's False Alarm Filter contradicts all 14 lens agents

**Problem**: `skills/code-audit/SKILL.md:369` says a filtered finding is "do not report as a
finding". All 14 lens agents, and the synthesizer's own contract, say the filter **demotes and never
deletes**, and that a NOTED item still gets a JSONL line. The skill is what an operator reads to
understand the round; as written it authorizes exactly the data loss the methodology exists to
prevent.

**Fix**: rewrite `:369` to the demote-never-delete formulation used in the lens agents, including the
sentence that a NOTED finding still gets a line at `sev: "NOTED"` / `status: "noted"`.

**Verification**: extend the T28-adjacent boilerplate comparison band to assert the skill's filter
paragraph matches the lens agents' phrasing.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `agents/edm-audit-synthesizer.md`'s Second-Pass False
Alarm Filter section and all 14 `agents/edm-audit-*.md` `## False Alarm Filter` sections -- confirm
the skill now agrees with them rather than the reverse.

---

### CA-029 (P1, L8): A crafted rule filename forges a `block` verdict

**Problem**: `bin/edm-hookify:222` (and `:226`, `:234`) interpolate the rule file path and the rule's
`name`/`action`/`message` into a tab-delimited, newline-separated record stream parsed by tag at
`:274-312`. None is checked for tab or newline. A repository shipping a file named
`x<LF>M<TAB>evil<TAB>block<TAB>PWNED.json` -- POSIX-legal on both platforms, matched by
`find -name '*.json'` -- makes jq print two lines, the second read as tag `M`, action `block`;
`HAD_BLOCK=1`, exit 2. **The file's content never has to be valid JSON, never has to set
`enabled: true`, and never has to set `"action": "block"`.** The same forge works from a rule `name`
containing `\nM\t...`, so a file that reviews as `warn` blocks anyway. That defeats the format's
load-bearing invariant, stated verbatim in `CLAUDE.md`: "a rules layer that could block by default
would hand every contributor the ability to wedge every other contributor's edits with one committed
file."

**Fix**: emit records from jq as one JSON object per line (`jq -c` / `@json`) and parse them with
`jq -r` on the bash side, so no field value can terminate a record. If the TSV shape is kept, reject
any rule path or field containing a tab or newline as a setup error before evaluation, and strip
`\t`/`\n`/`\r` from `$path`, `.name`, `.action` and `.message` inside the jq program.

**Verification**: a rule file with an embedded newline in its name must make `edm-hookify eval file`
exit 0 or 1, never 2. Repeat with an embedded newline in a `warn` rule's `name`.

**Files affected**: `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s "Hookify rule format (canonical)"
section, specifically the explicit-opt-in clause and the two-tier exit contract table;
`EDMV4-T43`/`T44` ACs.

---

### CA-030 (P1, L8): One malformed rule file disables every other rule

**Problem**: `bin/edm-hookify:247` -- the per-rule `try/catch` wraps only `fromjson` (`:220`).
`validate()` and `conds_match()` run unprotected, so any jq runtime error aborts the program and
`|| die "jq evaluation failed"` exits 1 for the whole directory. Four realistic authoring mistakes
trigger it: a top-level JSON array (the natural "all my rules in one file" mistake), a top-level
string, `"conditions": "foo"`, and an invalid Oniguruma pattern such as `"["`. Each produces exit 1
and **zero evaluated rules**, contradicting the file's own header at `:46-50` and `CLAUDE.md`'s "one
contributor's typo in one rule file cannot take down every other contributor's rules".

**Fix**: wrap the whole per-rule projection (validate plus conds_match) in `try ... catch` inside the
jq program, emitting an `E` record for that file only and continuing. Add type guards to `validate`:
require `($r|type) == "object"` and `($r.conditions|type) == "array"` with every element an object
carrying string `field`/`operator`/`pattern`.

**Verification**: a directory holding one array-shaped file and one valid enabled `block` rule must
exit 2 and name the bad file on stderr. Repeat for all four triggers.

**Files affected**: `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `bin/edm-hookify:46-50`'s isolation contract comment;
`CLAUDE.md`'s "malformed rule files are a setup error, never a block" subsection; `EDMV4-T43` ACs.

---

### CA-031 (P1, L12 + L3 + L1): An empty or unparseable payload degrades to `{}`

**Problem**: `bin/edm-hookify:216` -- `try fromjson catch {}` plus `$payload[$c.field] // ""` means an
empty, unparseable or field-drifted payload makes every field read as the empty string. Two opposite
consequences, each found by a different lens: `not_contains` conditions **match vacuously**, so a
`block` rule can fire on a parse failure (L3); and `contains` conditions stop matching, so a `block`
rule **silently stops enforcing** with a clean exit 0 (L12). Both are real and share the site and
root cause. L1 filed the same site NOTED on the grounds that it is unreachable through either
shipped consumer, since both guard on an empty payload first -- that bounds the blast radius but
does not close the defect, because `edm-hookify` is also a documented user-facing CLI.

**Fix**: distinguish "no payload" from "empty field". On a `fromjson` failure or an empty payload,
emit a setup-error record and exit 1 rather than proceeding with `{}`. Where a field is genuinely
absent from a well-formed payload, treat the condition as non-matching for both polarities rather
than letting `not_contains` succeed on absence.

**Verification**: drive `eval file` with (a) empty stdin, (b) `{`, (c) a well-formed payload missing
the conditioned field -- assert exit 1, exit 1, and exit 0-with-no-match respectively, for both a
`contains` and a `not_contains` rule.

**Files affected**: `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s per-event field table and its
`not_contains` semantics paragraph; `bin/edm-hookify`'s header contract; `EDMV4-T43` ACs.

---

### CA-032 (P1, L9): Turn budget parity still says all four verifiers run at `maxTurns: 50`

**Problem**: `CLAUDE.md:437-447` asserts the four read-only verifiers "run at `maxTurns: 50`, at
parity with the producer agents". Both halves are now false -- `edm-qc-auditor.md:11` is 150 and
`edm-implementer.md:12` is 200, raised by `EDMV4-T55`. The passage is a **standing instruction**
("Do not 'tidy' any of these four back down"), so a contributor obeying it restores the exact `50`
the wave-1 P0 remediation moved away from. D31 shows the smoke assertions were made floor-based and
value-agnostic; the prose was never swept.

**Fix**: rewrite `:437-447` to state the current values and the reason each differs, and keep the
do-not-tidy instruction pointed at the new floor rather than the old figure.

**Verification**: assert the documented figures match the agent frontmatter values, both read at test
time.

**Files affected**: `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T55` AC1/AC2 and the pack's cross-cutting
Documentation AC; `decisions.md` D31.

---

### CA-033 (P1, L11): plan Step 6 invokes `edm-repo-readiness` with no `Bash` grant

**Problem**: `skills/plan/SKILL.md:83-92` instructs the agent to probe and run
`edm-repo-readiness`, but `:8`'s `allowed-tools` grants only `Bash(edm-state *)`,
`Bash(edm-init *)` and `Bash(edm-validate-prefix *)`. Neither the probe nor the run is permitted.
Step 6's own fallback ("if the command is not on PATH ... skip this step entirely") makes the failure
**silent**: the section is simply never written, and absence is documented as authoritative.
`bin/edm-check-grants`'s Source 4 checks grant-without-instruction, never
instruction-without-grant, and `wave8-smoke.sh:3456-3467` asserts the prose exists but never the
frontmatter.

**Fix**: add `Bash(edm-repo-readiness *)` to `skills/plan/SKILL.md:8`. Extend `edm-check-grants`
Source 4 with the instruction-without-grant direction for scoped `Bash(<cmd> *)`: for every `edm-*`
binary named in a skill body inside a run instruction, require a matching scoped grant.

**Verification**: `edm-check-grants` must fail on a scratch copy with the grant removed.

**Files affected**: `plugins/edm/skills/plan/SKILL.md`, `plugins/edm/bin/edm-check-grants`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T39`/`T41`'s Step 6 ACs; `CLAUDE.md`'s
`allowed-tools` conventions section.

---

### CA-034 (P1, L11 + L2): Step 1b.5 consumes a readiness score produced later, by no named path

**Problem**: `skills/orchestrator/SKILL.md:123` says Step 1b.5 "may consult" the readiness score.
Two independent breaks. **Ordering**: Step 1b.5 is part of Step 1 (Intake, `:102`); the only producer
is Phase 1, dispatched at Step 2 (`:187`). Step 1b.5 is additionally "Skipped on resume" (`:104`) --
the only run in which a prior `planning.md` would exist -- so the two cases are disjoint: whenever
the score could exist, the consumer is skipped. **No read path**: `:123` names no artifact, no state
field and no command; the score lives only as prose in a `planning.md` section the orchestrator is
never told to read, and `:8` carries the same missing scoped grant as CA-033.

**Fix**: either (a) have Step 1b.5 run `edm-repo-readiness --json <tmp>` itself, adding
`Bash(edm-repo-readiness *)` at `:8` -- the rubric is repository-wide and needs no `planning.md`
(this is what CA-207 records as the obvious acquisition path); or (b) delete the coupling sentence.
Do not leave it as an unresolvable reference.

**Verification**: if (a), assert the orchestrator's grant covers the command and that Step 1b.5 names
the concrete acquisition step; if (b), assert the sentence is gone and no other file references the
coupling.

**Files affected**: `plugins/edm/skills/orchestrator/SKILL.md`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T41`'s ACs, whose smoke assertions
(`wave8-smoke.sh:3455-3500`) check only that the sentences exist in both files;
`skills/plan/SKILL.md:191-198`'s `## Repository Readiness` section, if the coupling is dropped.

---

### CA-035 (P1, L12 + L1): `detect-conditional-lenses` can wrongly declare L13 N/A

**Problem**: two mechanisms at `bin/edm-state`. (a) `:1762` -- `git ls-files ... || true` makes an
empty tracked set indistinguishable from an untyped stack, so a repository whose `git ls-files` fails
is silently scored N/A while the round still records `round_type=full`. (b) `:1725-1728` --
`_l13_applies` matches file-name markers with `grep -qx 'tsconfig.json'`, which only matches a
root-level path, while extension markers match at any depth. A TypeScript monorepo with only
`packages/app/tsconfig.json` is reported L13 N/A.

**This round is unaffected**: the orchestrator verified that `git ls-files` for this repository
returns no typed-stack marker at any depth, so L13 is genuinely N/A here and the
`13 run + 1 N/A = 14 = full` classification is sound. Severity reflects that a wrong N/A is not a
skipped lens but an **affirmatively required absence** -- `audit-round-complete`'s check (2) demands
`lens-L13.jsonl` be missing -- so a wrongly-N/A round still converges and archives with a lens
silently uncovered.

**Fix**: (a) distinguish a failed `git ls-files` from an empty result and `die` on the former rather
than scoring N/A. (b) match file-name markers at any depth (`grep -qE '(^|/)tsconfig\.json$'`),
matching the extension markers' behaviour.

**Verification**: a scratch monorepo with only `packages/app/tsconfig.json` must report L13
applicable; a scratch directory that is not a git repository must produce a hard error, not an N/A.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T24`'s ACs; `CLAUDE.md`'s conditional-lens
section and `agents/edm-audit-type-design.md:114-120`'s N/A contract, which both describe the
detection as reliable.

---

### CA-036 (P1, L12 + L7): `_rr_validate_output` captures `rc` and never reads it

**Problem**: `bin/edm-repo-readiness:144` captures `edm-state validate`'s exit status and discards
it, so a failed or phantom-prefix validate scores State health as **perfect** rather than unknown.
`edm-stop-gate` switches on the same documented 0/3/other contract, so the two consumers of one
contract disagree.

**Fix**: switch on the captured status -- 0 and 3 are meaningful results, anything else is a setup
error that must score the category unknown (and remove it from the denominator explicitly, with the
reason printed), never clean.

**Verification**: point the scorer at an unresolvable prefix and assert State health reports unknown,
not 100 percent.

**Files affected**: `plugins/edm/bin/edm-repo-readiness`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`/`T40`'s State-health rubric ACs;
`CLAUDE.md`'s `edm-state validate` exit-code contract section.

---

### CA-037 (P1, L12): A failed `get-coverage` raises the overall score

**Problem**: `bin/edm-repo-readiness:198` -- a failed `get-coverage` empties the framework signal,
marks Test stack and Coverage posture N/A, and removes both from the overall-score denominator. The
read failure therefore **raises** the score. A repository whose coverage data cannot be read scores
better than one whose coverage is genuinely poor.

**Fix**: distinguish "no coverage recorded" (legitimately N/A) from "the read failed" (unknown).
Score the latter as zero-with-diagnostic, or refuse to emit an overall score at all.

**Verification**: break `get-coverage` with a shim and assert the overall score falls or the command
refuses, rather than rising.

**Files affected**: `plugins/edm/bin/edm-repo-readiness`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`'s applicability rules and `T40`'s
score-derivation AC; the rubric description in `CLAUDE.md`.

---

### CA-038 (P1, L12): `CH_CALIBRATION_AVAILABLE` defaults true

**Problem**: `bin/edm-repo-readiness:312` defaults to true and only flips on a literal
`insufficient data` match, so a `metrics-report` failure of any other shape silently awards the
calibration-data points.

**Fix**: default to false and set true only on a positive signal; treat any non-zero
`metrics-report` status as unknown with a printed reason.

**Verification**: shim `metrics-report` to fail with an unrelated message and assert the calibration
points are not awarded.

**Files affected**: `plugins/edm/bin/edm-repo-readiness`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`'s Cost-history rubric AC.

---

### CA-039 (P1, L12): `edm-bash-gate`'s non-empty payload guard can never fire

**Problem**: `bin/edm-bash-gate:63` -- `{command: (.tool_input.command // "")}` always succeeds, so
the non-empty guard that follows can never fire. A payload-shape drift (a renamed field, a nested
`tool_input`) disables every bash-event rule with no signal at all: the gate allows everything and
says nothing.

**Fix**: project without the `//` default and test for `null` explicitly, so a missing field is
distinguishable from an empty command. Emit a one-line stderr diagnostic on the drift path.

**Verification**: drive the gate with `{"tool_input":{}}` and with `{"tool_input":{"cmd":"x"}}` and
assert the diagnostic fires in both, with exit 0 preserved.

**Files affected**: `plugins/edm/bin/edm-bash-gate`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s per-event field table for the `bash`
event; `bin/edm-bash-gate`'s `EDM-HELP` block, which documents the guard.

---

### CA-040 (P1, L12): A dying `validate` is skipped with `continue` and zero output

**Problem**: `bin/edm-stop-gate:115` -- a per-prefix `edm-state validate` that dies with a setup
error is skipped with `continue` and no output, so a systematic validate failure makes the Stop gate
exit 0 silently on every Stop. The gate that exists to catch blocking anomalies stops catching them
with nothing to say so.

**Fix**: emit one stderr line per skipped prefix naming the prefix and the status. Keep the
never-block contract -- this is a diagnostic, not a decision change.

**Verification**: CA-132's two-initiative fixture covers this; assert the diagnostic appears for the
broken prefix and the healthy prefix's verdict still governs.

**Files affected**: `plugins/edm/bin/edm-stop-gate`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T46` AC9; `bin/edm-stop-gate:154-157`'s
soft-exit rationale block.

---

### CA-041 (P1, L14): Four of six documented operators are never evaluated

**Problem**: `bin/edm-hookify:199` -- `op_match` implements six operators; only `contains` and
`not_contains` are ever evaluated by the real evaluator. `regex_match`, `equals`, `starts_with` and
`ends_with` have zero behavioural coverage. Two of them appear in fixtures, but those fixtures are
only read by `wave8-smoke.sh:661-849`, a hand-written bash re-implementation of the schema that never
invokes `edm-hookify`. A typo in any of the four unexercised jq arms (`startswith`/`endswith`/`test`)
ships green.

**Fix**: add one `edm-hookify eval` case per unexercised operator, each with a matching and a
non-matching payload so both truth values of every arm are observed. `regex_match` additionally needs
a case pinning Oniguruma-versus-ERE behaviour, which `CLAUDE.md`'s Hookify section warns about and
nothing tests.

**Verification**: mutate each arm in a scratch copy and confirm the corresponding case fails.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s operator table and its Oniguruma
divergence warning; `EDMV4-T43` AC covering the operator set.

---

### CA-042 (P1, L14): The `bash` and `stop` events have no match-path coverage

**Problem**: `edm-hookify eval bash` is invoked by no test in any suite. `eval stop` is invoked
exactly once (`wave8-smoke.sh:2475-2476`) with a deliberately malformed rule, asserting exit 1 -- so
no stop rule is ever driven to a match, and the empty-`conditions` branch at `bin/edm-hookify:209`
(the only legal shape a `stop` rule can take) is never taken. Consequently `edm-stop-gate:158-168`'s
block translation never runs either.

**Fix**: add (a) `eval bash` against `block-rm-rf-bash.json` with a matching and a non-matching
command; (b) `eval stop` against a zero-condition `warn` rule (exit 0, line on stderr) and a
zero-condition `block` rule (exit 2, line on stdout); (c) an `edm-stop-gate` case with one active
initiative and a matching stop `block` rule, asserting exit 2 and the
`[EDM] a stop-event hookify rule matched:` label. L14 confirmed all three pass by hand today.

**Verification**: as above; each case must fail when the corresponding branch is mutated.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T45` AC1/AC2's per-event owner table;
`CLAUDE.md`'s "Hooks behavior" `Bash` and `Stop` rows.

---

### CA-043 (P1, L14): The fail-open half of the hookify wiring is unproven

**Problem**: the deny half is proven (`wave8-smoke.sh:5484-5518`, T52 AC7b, a real `block` rule
producing a real `permissionDecision":"deny"`), but nothing asserts that a matched `warn` file rule
**still allows**, and nothing asserts that hookify's setup-error exit 1 does not escalate into a
denial. `wave8-smoke.sh:4698-4703` runs a `warn` rule but discards output and asserts only the call
count; the only proof of the non-escalation contract is `:2537-2571`, a harness whose translation
line is hand-retyped rather than extracted from the script. A regression that denied on any non-zero
hookify status would leave every existing assertion green while wedging every Edit in Phase 6 on one
contributor's typo. The same gap exists at `edm-stop-gate:164`.

**Fix**: extend the T52 AC7b fixture family with two negative cases through the real `edm-gateguard`
-- a matching `warn` rule (exit 0, empty stdout) and a malformed rule file (exit 0, empty stdout,
hookify's setup line on stderr). Repeat both for `edm-stop-gate`.

**Verification**: change the translation to deny on any non-zero status in a scratch copy and confirm
both new cases fail.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T44`'s two-tier contract ACs; `CLAUDE.md`'s
two-tier exit contract section.

---

### CA-044 (P1, L14): `EDM_GATEGUARD_STATE_DIR` is never exercised as a working redirect

**Problem**: `bin/edm-gateguard:202` -- the single test that sets the variable
(`wave8-smoke.sh:4327`) also sets `EDM_GATEGUARD=0`, so the script exits at `:81` before
`gg_state_dir` is ever called. T15 AC12 only asserts `CLAUDE.md` contains the string; AC7 only
asserts the warning text names it. Nothing proves the checked-file and denials-file land under the
override, and nothing proves the trailing-slash strip.

**Fix**: add a T15 case setting `EDM_GATEGUARD_STATE_DIR` to a writable scratch path distinct from
`CLAUDE_PLUGIN_DATA`, drive one first-touch denial, then assert `<override>/<key>.checked` and
`<override>/<key>.denials` exist and `${data}/run` is empty. Repeat once with a trailing slash.

**Verification**: as above. This case is also the natural home for CA-001's regression.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC12; `CLAUDE.md`'s
`EDM_GATEGUARD_STATE_DIR` bullet.

---

### CA-045 (P1, L14): A tab-less Phase-6 marker silently allows

**Problem**: `bin/edm-gateguard:110` -- only two marker shapes are ever driven, both well-formed.
L14 verified by hand that a marker line containing no tab byte **silently ALLOWS**:
`${MARKER_LINE#*$'\t'}` returns the whole line unchanged, the whole line then fails `[[ -d ]]`, and
the stale-marker branch at `:112-114` exits 0. A truncated or corrupted marker therefore disables
Phase 6 fact-forcing for the entire session with no diagnostic, and reads identically to the
legitimate branch-switch case. An empty marker file is also untested (it denies).

**Fix**: decide the contract and assert it. If "malformed reads as stale" is intended, say so at
`:110` and add the two cases (tab-less single token, zero-byte file) asserting the intended decision
explicitly. If it is not intended, treat a marker that does not parse into three fields as a setup
error with a stderr diagnostic.

**Verification**: the two new cases; plus confirm the zero-byte case's current deny is deliberate.

**Files affected**: `plugins/edm/bin/edm-gateguard`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC11's stale-marker clause;
`bin/edm-state`'s `_edm_marker_write` format comment, which defines the three-field shape.

---

### CA-046 (P1, L14): The documented `[<PREFIX>]` argument is never passed by any test

**Problem**: all 12 `edm-repo-readiness` invocations in `wave8-smoke.sh` are argument-free or
`--json <path>` only. Untested: the `prefix not found or unresolvable` die and its exit-2 contract
(`:108-110`), `_rr_active_prefixes`' single-prefix branch (`:130-132`), the prefix-scoped
`edm-lint-artifacts` invocation (`:329-330`), the `unexpected extra argument` die (`:88`), the
`Scope: initiative ...` header (`:476-478`) and the non-null `prefix` field in the JSON (`:465`).

**Fix**: add a scratch-repo case scoring a real initiative by prefix -- assert `.prefix` in the JSON
and the scoped header on stdout -- plus a `check_fails` for an unresolvable prefix asserting exit 2.

**Verification**: as above.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38` AC6's exit-code assertions, which cover
unknown-flag and `--json`-with-no-path but not the prefix arm.

---

### CA-047 (P1, L14): Test stack and Coverage posture are never exercised when applicable

**Problem**: on the only repository the tests score, both categories report `applicable:false`. So
`TESTSTACK_UNIT_FOUND`/`TESTSTACK_OTHER_FOUND` (`:243-250`), both awk parsers over
`edm-state get-coverage` (`:202-224`, flat and per-epic shapes), `_rr_layer_max_pct` (`:230-234`) and
`_rr_layer_meets_target` (`:237-241`) never see input that makes them true, and the `applicable:true`
arm of the category mean is never taken. `wave8-smoke.sh:3190-3195` compounds it: with no inapplicable
category found it prints a soft `NOTE` rather than failing.

**Fix**: add a scratch initiative with `edm-state record-test-coverage` rows for unit, component and
integration in both the flat and per-epic shapes plus a recorded `test_frameworks_detected`, then
assert both categories flip to `applicable:true`, that `unit-coverage-meets-target` flips as the
percentage crosses the target, and that the overall mean divides by 6 rather than 4.

**Verification**: as above; also replace the `:3190-3195` soft NOTE with a `fail` (shares CA-019's
shape).

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`'s six-category rubric AC and `T40`'s
applicability ACs.

---

### CA-048 (P1, QC-W04): T57 AC3 -- no negative fixture proves any retargeted assertion discriminates

**Problem**: AC3 requires "a fixture in which the harvested entry is absent from the new location
must fail it. **Passing after the retarget is not evidence on its own.**" No such fixture exists for
any retargeted group. What shipped instead is a *seed-unchanged* discriminator, added twice
(`wave7-smoke.sh:3820-3825` and `:3949-3954`) -- a useful control proving the write target moved, but
the opposite direction from the one AC3 names. Grepping the whole T57 diff for control language
returns exactly three hits, none of them a negative fixture. This matters because the retarget
introduced assertion shapes that pass on empty input: the two `check_absent` calls against
`$(cat "$delta")` at `:3927` and `:3944` pass vacuously if the delta is empty, surviving today only
through an adjacent guard -- an inherited property, not a demonstrated one, which is exactly the
distinction AC3 was written to force.

**Fix**: for each retargeted group, add a case that truncates `$delta` after a successful
`update-patterns` run and re-runs only the assertion block, confirming it reports a failure.
Prioritise `:3927` and `:3944`. Keep the seed-unchanged discriminators -- they control a different
risk and are not a substitute.

**Verification**: each new case must FAIL on the truncated delta and PASS on the populated one.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T57` AC3 and AC8 (AC8's `run-all.sh` clause
closes in the same pass, since remediating AC3 requires re-running wave7 anyway).

---

### CA-049 (P1, QC-W05): T50 AC2 -- `T50_BASH4_RE` is a third literal and has already drifted

**Problem**: AC2 says the assertion "**references** `T61_BASH4_RE` ... and **never re-encodes the
alternation as a second literal that can drift**". `wave8-smoke.sh:5005` is a third independent
literal, and the comment at `:5001-5003` states the deviation as deliberate. **It has drifted in both
directions**: it omits the `\{fd\}` arm `T61_BASH4_RE` carries -- so the `bin/tests/` self-check, the
one gap this ticket exists to close, does not check `{fd}` redirection at all -- and it adds
`local[[:space:]]+-A` that `T61_BASH4_RE` lacks.

**Fix**: re-read the literal from `wave7-smoke.sh:1083` at test time
(`grep -m1 '^T61_BASH4_RE=' | cut -d= -f2-`) rather than retyping it.

**Verification**: add an assertion that the two literals are byte-identical, computed at test time;
confirm `{fd}` is now caught by the `bin/tests/` self-check.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T50` AC2; the `:5001-5003` comment stating the
deviation, which must be removed rather than left describing a rejected choice.

---

### CA-050 (P1, QC-W05): T50 AC5 -- the sweep excludes the file the AC names

**Problem**: AC5 requires the process-substitution sweep to cover "the five new files **plus
`wave8-smoke.sh`**". `T50_PROCSUB_HITS` at `wave8-smoke.sh:5093` pipes through `grep -v '/tests/'`,
filtering out `bin/tests/wave8-smoke.sh` from its own check. The substance holds today -- the only
match in the file is the positive control's own literal at `:5100` -- but the assertion cannot detect
a regression in the file it was written to protect.

**Fix**: run `t50_procsub` against `$T50_SELF` explicitly, mirroring the `t50_self_scan` shape already
used at `:5057`.

**Verification**: add a real process substitution to a scratch copy of `wave8-smoke.sh` and confirm
the sweep fires.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T50` AC5.

---

### CA-051 (P1, QC-W05): T51 AC1 -- the interpreter sweep excludes `bin/tests/`

**Problem**: `t51_scan` at `wave8-smoke.sh:5156-5160` pipes through `grep -v '/tests/'`, so eleven
files including three smoke suites and `timing.sh` sit outside a check written against "every file
under `plugins/edm/bin/`". **That AC2 grants a `perl` exemption for `bin/tests/timing.sh` is proof
`bin/tests/` was meant to be in scope** -- an exemption is only needed for something otherwise
caught. A `python3` line added to any suite is invisible.

**Fix**: drop the `/tests/` filter from `t51_scan` and handle `timing.sh`'s `perl` through AC2's
existing content-resolved exemption, which already works.

**Verification**: add a `python3 -c` line to a scratch copy of a suite and confirm the sweep fires.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T51` AC1's "every file under `bin/`" clause.

---

### CA-052 (P1, QC-W05 + L8): Unguarded `perl` in the plugin's only enforcement mechanism

**Problem**: `wave6-smoke.sh:3501` and `:3511` both run `printf '%s' "$g18_row" | perl -pe
's/\\\|//g'` with **no `command -v perl` guard and no fallback** -- a hard dependency on a binary
outside the pinned `bash`/`jq`/`git` set, in a suite that IS the enforcement (there is no CI).
`bin/tests/timing.sh:61,77` guards its own perl use properly. The T51 implementer recorded this site
in a comment at `wave8-smoke.sh:5185-5190` and scoped the sweep past it rather than failing on it --
**documenting a known violation inside the assertion that exists to catch it converts the assertion
into a note.**

**Fix**: replace both with the `awk` the file already pipes into (`awk -F'\\|' '{gsub(/\\\\\\|/,"");
print NF-2}'`) or a bash parameter expansion. Then let CA-051's un-filtered sweep cover the file.

**Verification**: run `wave6-smoke.sh` with `perl` removed from `PATH` and confirm the G18/CA-378
markdown-cell count check still passes.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T51` AC2 clause (a) -- either it now enforces
what it says, or its text is rewritten to state what it enforces; the `:5185-5190` comment must go.

---

### CA-053 (P1, QC-W05 + L8 + L4 + L14): Unpaired BSD-only `stat -f` in the T43 AC9 snapshot

**Problem**: `wave8-smoke.sh:2073` -- `t43_ac9_snapshot()` runs
`find . -type f -exec stat -f '%N %z %m' {} \;`. `stat -f` with those specifiers is BSD-only; on GNU
it means `--file-system` and the format is consumed as a filename operand, so every invocation errors
into `2>/dev/null` and both snapshots compare **equal-and-empty**. The no-write assertion built on
them passes vacuously. It escapes both divergence guards for the same reason: T51's sweep filters
`/tests/` (`:5193`) and T61 AC11's filters `/tests/` (`wave7-smoke.sh:1223`).

**Adjudication**: L4 and L14 both demoted this to NOTED on the grounds that the paired positive
control at `:2096-2101` would itself fail on Linux, surfacing the vacuity. Wave-5 QC and L8 filed it
actionable, and they are right: the control adds a file, so it detects a change in file *count*,
while the vacuity being masked is the inability to detect a *modification*. Retained at P1 with the
higher severity governing, per multi-lens merge.

**Fix**: use the `stat -c ... || stat -f ...` pair shape `edm-gateguard:232` establishes, which both
sweeps then exempt by construction. Better still, drop `stat` and snapshot with `harness_sha256`
(`_harness.sh:270-283`), which detects modifications as well as additions.

**Verification**: modify an existing file between the two snapshots and assert the check fails --
today it passes on GNU and detects nothing.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T51` AC4/AC5; `EDMV4-T43` AC9;
`decisions.md` D43's Linux-untested record.

---

### CA-054 (P1, QC-W05): T51 AC8 -- no jq-off-`PATH` test for three of five scripts

**Problem**: AC8 requires one test per script. Present: `edm-gateguard` (`wave8-smoke.sh:3387`,
`:4490`) and `edm-stop-gate` (`:2338`, `:2351`). Missing entirely for `edm-hookify`,
`edm-repo-readiness` and `_edm-datadir-lib.sh`. The **code** is correct -- `edm-hookify:139` dies via
a `die()` defaulting to exit 1 and `edm-repo-readiness:65` via one defaulting to exit 2 -- so this is
a test gap, but AC8 is an assertion about tests and two blocking-adjacent scripts have none.

**Fix**: add jq-off-`PATH` cases for `edm-hookify` (expect exit 1), `edm-repo-readiness` (expect
exit 2) and `_edm-datadir-lib.sh`.

**Verification**: each new case must fail if the corresponding `require_jq` guard is removed.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T51` AC8's "one test per script" clause.

---

### CA-055 (P1, QC-W05): T52 AC4 -- four new fixture files have no effective ASCII coverage

**Problem**: AC4 forbids leaving any new file under neither mechanism. Two gaps. (a)
`bin/edm-repo-readiness` is absent from the assignment comment at `wave8-smoke.sh:5330-5338` -- a
record defect only, since AC2's live `find` does cover it. (b) **Materially worse**:
`bin/tests/fixtures/code-audit/lens-L12.jsonl`, `lens-L13.jsonl`, `lens-L14.jsonl` and
`lenses-run.txt` -- four files added by `EDMV4-T32` -- are covered by neither. AC1's `--path` sweep
cannot collect them (`collect_md_files` filters `-name '*.md'`) and AC2's byte scan explicitly
excludes `bin/tests/fixtures/*` at `:5382`. Their only nominal coverage is CA-017's assertion, which
is vacuous on macOS. **These four files have no effective ASCII coverage at all on the plugin's
primary platform.**

**Fix**: narrow the `:5382` exclusion from the whole `fixtures/` tree to the specific
fenced-code-block corpora that need it (`mermaid/`, `lint-lib/`), which brings `fixtures/code-audit/`
under the byte scan in one edit. Add `edm-repo-readiness` to the `:5330` assignment comment.

**Verification**: inject a runtime-assembled non-ASCII byte into `fixtures/code-audit/lens-L12.jsonl`
and confirm the byte scan fires.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T52` AC4's coverage assignment and AC10/AC11's
uncovered-surface record in `CLAUDE.md:1176-1200`.

---

### CA-056 (P1, QC-W05 + L8): `edm-hookify`'s `list` and setup-error arms bypass the sanitizer

**Problem**: T52 AC6 routed matched-rule lines through `hookify_emit_match` (`:259-270`). Two other
emission sites still write attacker-controlled bytes raw. `bin/edm-hookify:285-287` -- the `L)` arm
runs a bare `echo "$_rest"`, emitting the rule's `name` (`$parsed.name // $path`) to stdout with no
sanitization; **reproduced live by wave-5 QC**: a rule whose `name` carries a non-ASCII byte puts
that byte on stdout unmodified. `:282` interpolates `${_epath}` and `${_ereason}` -- raw JSON values
from the rule file -- into stderr, so ESC survives and a rule file with an unknown key named
`<ESC>]0;pwned<BEL>` rewrites the operator's terminal title. Separately, `echo "$_rest"` lets a rule
`name` of exactly `-n` or `-e` be consumed as a builtin option. The AC6 check at `:5642` cannot see
any of this -- it scans only `_mname`, `_maction` and `_mmessage`, never `_rest`.

Blast radius is bounded today (`list` has no JSON control channel and `eval` emits only `M)` lines),
but **AC6's stated premise is false as written**.

**Fix**: extract the sanitizer into a `hookify_scrub` helper so there is one filter, not three, and
route `:282` and `:285-287` through it. Replace `echo "$_rest"` with `printf '%s\n' "$_rest"`. Add
`_rest` to the `:5642` variable list so the check covers the path it missed.

**Verification**: run `edm-hookify list` against a rule whose `name` carries a real non-ASCII byte
and an ESC sequence, and assert the output is pure ASCII.

**Files affected**: `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T52` AC6's single-emit-point premise and its
Technical Notes ("Verify that single-emit-point property holds before writing the sanitizer");
`CLAUDE.md` Sec."Artifact content conventions".

---

### CA-057 (P1, QC-W05): T53 AC4 -- no hook guard is ever executed

**Problem**: AC4 requires a case "asserting its `command -v` guard **exits 0** when the delegate
script is off `PATH`". All three assertions are `jq`-extract-then-string-compare against
`hooks/hooks.json`: `edm-gateguard`'s at `wave8-smoke.sh:3332-3341`, `edm-bash-gate`'s at `:4584`,
`edm-stop-gate`'s at `:2234`. They verify the guard's **text**, never its behaviour. A guard with a
typo (`comand -v`), or one whose delegate name no longer matches the installed binary, passes all
three and then fails open -- or worse, blocks -- at runtime.

**Fix**: for each of the three, run the extracted command string under `/bin/bash -c` with a `PATH`
excluding the delegate and assert exit 0. Three lines each, turning a text check into the contract
check `CLAUDE.md` Sec."Hooks behavior" actually records.

**Verification**: introduce a typo into a scratch copy of one guard and confirm the new case fails.

**Files affected**: `plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T53` AC4; `CLAUDE.md` Sec."Hooks behavior"'s
guard contract.

---

### CA-058 (P1, QC-W05): T53's two runtime Definition-of-Done checks were never performed

**Problem**: AC7 (scratch-tree isolation) and AC8 (`run-all.sh` green on macOS under `/bin/bash`
3.2.57) are both runtime-only and neither was performed. The recorded evidence in commit `6386a52`
("3241 passed, 0 failed across 8 suites, verified twice consecutively on a quiet tree") covers the
aggregate but **not the interpreter**, which is the specific thing AC8 names -- a run under a
Homebrew bash 5.x would produce the same line and prove nothing about the floor. No artifact records
the AC7 snapshot having been taken at all.

**Fix**: (AC7) snapshot `git status --porcelain`, run `wave8-smoke.sh` **in isolation** (not via
`run-all.sh`, whose pass through `wave6-smoke.sh:4087-4099` deliberately mutates
`docs/canonical-sections.md`), snapshot again, and assert no new entry is attributable to it. Note
the suite writes into the live `SRD/` tree via `edm-state init T52NA` at `:5545`, which must be
isolated first. (AC8) run `/bin/bash plugins/edm/bin/tests/run-all.sh` and record the aggregate
**and** `/bin/bash --version` together in `decisions.md`.

**Verification**: both results recorded in `decisions.md` alongside D43, with the interpreter string
verbatim.

**Files affected**: `SRD/edm/EDMV4__ecc-integration/decisions.md`,
`plugins/edm/bin/tests/wave8-smoke.sh`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T53` AC7/AC8; `srd.md` Sec.3.4 DoD items 1-2.

---

### CA-059 (P2, L6): Stale `file:line` citations in prose

**Problem**: `CLAUDE.md:1309` cites the `ratio=UNMEASURABLE` refusal at `timing.sh:419-423`; it is at
`:429-433`. `docs/ecc-integration-analysis.md:1026`'s own citation *correction* asserts "the
current-tree citations are `:5607` and `:5640`"; the two symbols now sit at `bin/edm-state:6070` and
`:6113` (also cited stale at `:364` and `:372`). This is the CA-416 stale-citation class recurring.

**Fix**: correct all four citations. Prefer by-name or by-symbol citation over `file:line` wherever
the reference survives a rewrite, which is what makes the class recur.

**Spec/AC text to sweep in the same commit**: `EDMV4-T23` AC4 and the G10/CA-340 citation-ban band
(CA-060), which is the mechanism that was supposed to catch these.

---

### CA-060 (P2, L6): The G10/CA-340 comment claims a scope the regex does not have

**Problem**: `wave7-smoke.sh:8931`'s comment says the citation ban is "scoped to exactly that shape
(this plugin's own `bin`/`tests`/`evals` scripts)". The regex names a subset and misses 12 shipped
scripts, including a live citation at `bin/edm-repo-readiness:48`.

**Fix**: widen the regex to the scope the comment claims, or narrow the comment to what the regex
enforces. Do not leave them disagreeing -- that is how CA-059's citations survived.

**Spec/AC text to sweep in the same commit**: the `:8931` comment itself; `EDMV4-T23`'s citation ACs.

---

### CA-061 (P2, QC-W04): T14 AC7's clean-room claim is false and AC2 mandated the copy

**Problem**: AC7 states "No text is copied verbatim from `gateguard-fact-force.js`". The `Write`
fact-1 string at `bin/edm-gateguard:324` is word-for-word identical to ECC `:1085`, differing only by
an appended `(${path})`; `:328` and `:333` are minimal-edit paraphrases with long verbatim runs.
**AC2 and AC7 are in direct conflict** -- AC2 dictates the exact phrase AC7 forbids, so the
implementer could not satisfy both. That is a ticket defect, not an implementer error. Separately,
`CLAUDE.md`'s "Prompt conventions (house style)" bases its MIT NOTICE dormancy argument on AC7; that
basis is wrong (there is no licence exposure -- GateGuard is MIT and attribution is already recorded
at D13/D14 -- but the stated reason is inaccurate). Root cause: **no assertion anywhere checks AC7.**

**Fix**: reword `Write` fact 1 and tighten `:328`/`:333`, then amend AC2 to describe the fact's
*content* rather than dictate its wording -- both under gate change control per
`CLAUDE.md` Sec."Unverifiable acceptance criteria (D15)". Either way add the assertion AC7 never had:
a pinned list of phrases the fact set must not contain, paired with a positive control the way AC3's
check at `wave8-smoke.sh:4125-4129` already is.

**Spec/AC text to sweep in the same commit**: `EDMV4-T14` AC2 and AC7; `CLAUDE.md`'s "Prompt
conventions (house style)" NOTICE-dormancy clause.

---

### CA-062 (P2, L9 + QC-W04): Two `NEEDS-NEW-TICKET` comments annotate assertions that now pass

**Problem**: `wave7-smoke.sh:3664-3671` and `:4675-4678` both claim to guard "a genuine,
currently-shipped defect in the committed file itself". **Corrected by wave-4 QC**: commit `b697142`
moved the offending entry and the auditor re-derived the four-heading contract by hand over all five
`docs/audit-patterns/*.md` files -- every one has exactly 4 `##` headings and 0 orphan `###`
headings. The assertions currently pass. L9 filed this as an AC6 violation ("two sites name the
literal `NEEDS-NEW-TICKET` and no follow-on identifier was reserved"); the corrected position is that
**AC6 is met at tip** and these are stale comments that will send a future reader hunting for a fixed
defect.

**Fix**: rewrite both comments to record the defect as closed by `b697142` and drop the
`NEEDS-NEW-TICKET` marker. If a residual obligation remains, reserve a real prefix as this initiative
did for `EVALB`, `CAMGAP`, `LINUXV` and `EDMRT`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T57` AC6; `decisions.md` (no row exists for
this boundary, unlike the other four).

---

### CA-063 (P2, L9): `edm-bash-gate` is a sixth new `bin/` script no ticket names

**Problem**: `bin/edm-bash-gate` (76 lines, plus a third `PreToolUse` matcher block) is a justified
consequence of `EDMV4-T45` AC3/AC9, but no ticket names it as a deliverable and three cross-cutting
ACs enumerate the new `bin/` set by name and exclude it: `T50` AC1 (five files), `T52` AC4 ("the four
new `bin/` scripts"), `T53` AC3 (three cases for four named scripts).

**Fix**: do not remove it -- it is the only route by which the `bash` event ships without touching the
`git commit` block `T45` AC5 pins byte-identical. Amend the three name lists to five/six, or file a
follow-on ticket owning it explicitly. This is the enumeration half of CA-004 and CA-005 and belongs
in the same commit.

**Spec/AC text to sweep in the same commit**: `EDMV4-T50` AC1, `EDMV4-T52` AC4, `EDMV4-T53` AC3,
`EDMV4-T45`'s Target Components; `srd.md`'s new-script inventory.

---

### CA-064 (P2, QC-W04): T15 AC3's "zero filesystem reads" is imprecise and unasserted

**Problem**: `bin/edm-gateguard:50-51` spawns `dirname` and sources `_edm-cli-lib.sh` **before**
either kill switch at `:80-85`, so "zero filesystem reads beyond its own environment" is not
literally true. The AC's enumerated conditions are all met, so this is not a FAIL -- but
`wave8-smoke.sh:4272-4278` compares the kill switch only against the `_edm-datadir-lib.sh` source at
`:88`, never against `:51`. That the test authors had to stub `dirname` into the fakebin (`:4283`)
shows they knew a spawn occurs there.

**Fix**: reword AC3 to its enumerated conditions (no marker `stat`, no session-state read, exit 0 and
empty stderr under mode-000 paths), and extend the ordering assertion to cover `:51`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC3; the `:4272-4278` assertion comment.

---

### CA-065 (P2, QC-W04): The T57 follow-on defect was closed by an unticketed commit

**Problem**: commit `b697142` ("Move a harvested pattern entry into the section it belongs in")
carries no `{PREFIX}-T{NN}` ID in its subject and records a wave7 delta in its body. T57 AC6's
condition at tip is therefore satisfied by work T57 did not do and that no ticket owns.

**Fix**: record the commit against a ticket retrospectively in `decisions.md`, or file the follow-on
`EDMV4-T{NN}` and reference it. The outcome is correct; the change-control gap is the finding.

**Spec/AC text to sweep in the same commit**: `decisions.md` (add the row); `CLAUDE.md`'s
commit-convention section on `{PREFIX}-T{NN}` subjects.

---

### CA-066 (P2, QC-W04): No assertion pins the jq-spawn count on the gated allow path

**Problem**: `bin/edm-gateguard:394` runs a second `jq -c` on every gated call to project `$PAYLOAD`
into hookify's field shape. This does not violate T45 AC1 as written (stdin is not re-read), but it
undercuts the cost intent, and AC6's spy covers only the marker-absent path.

**Fix**: add a jq-spawn-count spy on the **gated** allow path and pin the count, mirroring AC6's
existing spy shape. If two spawns are accepted, record the figure and its rationale.

**Spec/AC text to sweep in the same commit**: `EDMV4-T45` AC1/AC6; SRD Sec.9.1/9.3's allow-path
budget, which CA-212 records as measured only by a manual `timing.sh` mode.

---

### CA-067 (P2, QC-W04): T57 AC7 pins an absolute suite count later tickets invalidated

**Problem**: AC7 states wave8 holds at `515/0`; it is `735/0` at tip because `T14`, `T15`, `T45`,
`T53` and `T28` each appended banded sections afterwards. The substantive claim (unaffected by *this*
ticket) is provable from the commit stat, but the AC as literally written can never be re-verified.

**Fix**: amend AC7 to pin a delta or a touched-files claim rather than an absolute suite count, and
adopt that as the convention for any successor AC.

**Spec/AC text to sweep in the same commit**: `EDMV4-T57` AC7; the ticket-writing guidance in
`CLAUDE.md` on unverifiable acceptance criteria (D15).

---

### CA-068 (P2, QC-W04): T15 AC9's help-block assertion is looser than the AC

**Problem**: `wave8-smoke.sh:4493-4494` greps the whole of `edm-gateguard` for `once a marker is
present`, not the `EDM-HELP-BEGIN`/`END` block the AC names. The phrase does occur once, inside the
block, so the AC is satisfied -- but the assertion would still pass if the sentence moved out into a
code comment.

**Fix**: scope the grep to the extracted help block, using the extractor the `--help` machinery
already provides.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC9.

---

### CA-069 (P2, QC-W05): The T28 Scope-paragraph check leaves 44 characters unchecked

**Problem**: `wave8-smoke.sh:4793-4794` matches `...say so in a` and `rather than quietly narrowing,
widening or transforming it.` but never the 44 characters between them. A lens rewriting that middle
clause passes the contract check. The wrap tolerance is justified -- `edm-audit-security.md:20-21`
genuinely hard-wraps this paragraph (CA-110) -- but the fix is a third grep, not a two-sided
approximation. Not currently exploitable: `wave7-smoke.sh:4955` asserts exactly one unique phrasing
tree-wide.

**Fix**: add a third grep for the middle segment.

**Spec/AC text to sweep in the same commit**: `EDMV4-T28` AC5.

---

### CA-070 (P2, QC-W05 + L7): The extra-headings waiver comment understates its own extent

**Problem**: `wave8-smoke.sh:4962-4965`'s comment justifying the `HEADING_ORDER` subsequence
tolerance names 3 files and 2 heading strings. The live extent is **7 files and 4 heading strings** --
adding `edm-audit-runtime.md` and `edm-audit-spec.md` (`## Process`), `edm-audit-test-quality.md`
(`## Fixing gaps found here`) and `edm-audit-wiring.md` (`## Tracing Method`), one of them in a
different position. L7 reached the same count independently. The waiver itself is correct; the
understated justification is what stops a later reader re-deriving it.

**Fix**: correct the comment to 7 files and 4 names, deriving the list from a live glob if practical.

**Spec/AC text to sweep in the same commit**: the `:4962-4965` comment; `EDMV4-T28`'s
heading-order AC.

---

### CA-071 (P2, L4 + QC-W05): T28 contract-check tags overclaim control backing

**Problem**: the T28 preamble at `wave8-smoke.sh:4742` claims every contract check is control-backed.
L4 counted 18 of 33 violation tags with no negative fixture. **Wave-5 QC executed the checker** --
extracting `t28_contract_violations` into a standalone harness and running every fixture -- and
narrowed the genuinely unexercised set to **nine tags**: `DISALLOWED_TOOLS`, `EFFORT`,
`OUTPUT_JSONL_PATH`, `SCHEMA_LENS_ID`, `ASCII_REMINDER`, `JSONL_STATUS_RULE` and all three
`NA_CONDITIONAL_*`. The last three matter most: they are the **sole machine enforcement of L13's
conditional-lens carve-out** (the "cost is never a reason to skip this lens" guard) and nothing proves
they can fire.

**Fix**: one negative fixture per unexercised tag on a scratch L13 copy, the three `NA_CONDITIONAL_*`
tags first. Correct the `:4742` preamble to state what is and is not control-backed.

**Spec/AC text to sweep in the same commit**: `EDMV4-T28` AC12; the `:4742` preamble.

---

### CA-072 (P2, L10 + L7 + QC-W05): The ASCII sanitizer has five copies and no single owner

**Problem**: the literal `LC_ALL=C tr -c '\011\012\015\040-\176' '?'` is hand-copied five times
across `edm-gateguard:163`, `edm-hookify:262-264` and `edm-stop-gate:82`. All five are byte-identical
today (wave-5 QC diffed them), so there is no live drift -- but the AC6 checks key on the marker
string `LC_ALL=C tr -c`, so a copy that drifts in its *character set* while keeping the marker still
passes every assertion. `edm-bash-gate:72` is the fourth consumer and has **no sanitizing emit point
at all** -- `printf '%s\n' "$HOOKIFY_OUT" >&2` re-emits whatever hookify wrote. That is not an AC6
violation (bash-gate is outside T52's Target Components and is transitively safe because
`hookify_emit_match` sanitizes first), but the safety is **transitive and unasserted**, so CA-056's
`L)` defect or any future hookify stdout path propagates straight through it.

**Fix**: extract one `edm_sanitize_ascii` into `_edm-cli-lib.sh` and call it from all four consumers;
give `edm-bash-gate` a named `bash_gate_emit_blocking` that routes through it. Assert the character
set, not just the marker string.

**Spec/AC text to sweep in the same commit**: `EDMV4-T52` AC6/AC7's three-consumer scope (it must
become four); `CLAUDE.md` Sec."Artifact content conventions".

---

### CA-073 (P2, L1 + L8): Unquoted array split applies pathname expansion to the exempt globs

**Problem**: `bin/edm-gateguard:300` -- `glob_list=($globs)` is unquoted, so bash applies **both**
word splitting (intended, on `IFS=,`) and pathname expansion (not intended). With globstar off,
`**/SRD/**` behaves as `*/SRD/*`: in any repository where `docs/SRD/design.md` exists relative to the
gate's cwd, the glob EXPANDS to that literal filename and stops being a pattern, so `case "$path" in
$gg)` at `:307` can only match that one path. The `SRD/`, test-tree, `dist`/`build`, `node_modules`
and `.git` exemptions silently stop working and the gate denies edits to exactly the trees it was
configured to leave alone. The `# shellcheck disable=SC2206` at `:299` justifies only the
word-splitting half.

**Fix**: `set -f` immediately before the assignment and `set +f` immediately after (restoring the
previous state), or replace the split with a `while IFS= read -r g` loop over
`printf '%s\n' "${globs//,/$'\n'}"`, which splits without globbing.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC4/AC5; the `:299` shellcheck-disable
comment, which must name both halves.

---

### CA-074 (P2, L1): `audit-round-start` does not subtract `lenses_na` from the materialized set

**Problem**: `bin/edm-state:4822` materializes `lenses` to `ALL_LENS_IDS` without subtracting
`lenses_na` and never checks disjointness, so `--na-lenses` without `--lenses` guarantees an
irreversible partial downgrade at completion.

**Fix**: subtract `lenses_na` when materializing, and `die` on a non-disjoint pair.

**Spec/AC text to sweep in the same commit**: `EDMV4-T23`/`T24` ACs; `skills/code-audit/SKILL.md`
Step 1's `--na-lenses` usage.

---

### CA-075 (P2, L1 + L3): Marker reconciliation has no recreate and a lock-free race

**Problem**: `bin/edm-state:4611-4615` -- SessionStart reconciliation removes a stale Phase-6 marker
without recreating one for a genuinely active phase-6 initiative in the same run, leaving GateGuard
disabled. The scan-then-check-then-delete sequence additionally holds no lock, so a `phase-start 6`
landing between scan and reconcile has its fresh marker deleted.

**Fix**: recreate the marker for any initiative found at phase 6 during the same reconciliation, and
run the sequence under the state lock.

**Spec/AC text to sweep in the same commit**: `EDMV4-T12`'s marker-lifecycle ACs; `CLAUDE.md`'s
Phase-6 marker section.

---

### CA-076 (P2, L1): `validate()` never type-checks `enabled` nor validates `action`

**Problem**: `bin/edm-hookify:227` -- a string `"true"` silently disables a rule (it is not the
boolean `true`), and any non-literal `block` action silently degrades to `warn`. Both fail toward
non-enforcement with no diagnostic.

**Fix**: require `(.enabled|type) == "boolean"` and `.action` in `["warn","block"]`, emitting a setup
error otherwise. This lands naturally with CA-030's type guards.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s rule-schema table; `EDMV4-T42`/`T43` ACs.

---

### CA-077 (P2, L1 + L7 + L12): Unguarded `jq` substitutions abort the gate outside its exit contract

**Problem**: four unguarded `jq` command substitutions on the gated path (`bin/edm-gateguard:361`,
`:394` among them) abort under `set -euo pipefail` with jq's exit 5 -- outside the documented 0/1/2
contract, with the message suppressed by `2>/dev/null`. Zero bytes on stdout and stderr: the gate
fails open invisibly. `edm-bash-gate` guards the structurally identical projection with `|| exit 0`
plus an emptiness check, so the family already has the right shape.

**Fix**: adopt `edm-bash-gate`'s guarded shape at all four sites: capture, check status, and either
degrade to allow with a diagnostic or `die` inside the documented contract. Never let jq's own status
escape.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC9/AC10's exit contract; the `EDM-HELP`
block's 0/1/2 table.

---

### CA-078 (P2, L1 + L8): Unquoted `ls` iteration makes the citation check pass vacuously

**Problem**: `bin/edm-check-grants:659` -- `_cite_files="$(ls ...)"` followed by unquoted
`for _cf in $_cite_files` word-splits on IFS. When `PLUGIN_ROOT` contains a space (routine on macOS,
e.g. `~/Dev Projects/marketplace`), every path fragments, `[[ -f "$_cf" ]] || continue` skips all of
them, and the whole EDMV4-T04 citation-orphan check **reports clean while scanning zero files**.

**Fix**: iterate the globs directly -- `for _cf in "${PLUGIN_ROOT}"/agents/*.md
"${PLUGIN_ROOT}"/skills/*/SKILL.md; do [[ -f "$_cf" ]] || continue; ...` -- dropping `ls` and the
intermediate variable entirely. Add a scanned-file count assertion so zero can never read as clean.

**Spec/AC text to sweep in the same commit**: `EDMV4-T04` AC11.

---

### CA-079 (P2, L1): The non-PCRE fallback enforces a different predicate

**Problem**: `wave8-smoke.sh:5359` -- `t52_ascii_scan`'s non-PCRE fallback branch also flags ASCII
control bytes, so the AC2 assertion means something different on macOS than on GNU grep. CA-017's fix
routes more callers through this function, which makes the divergence matter more.

**Fix**: align the two branches on one predicate (bytes outside `\x00-\x7F`), or state the difference
at the site and in the AC.

**Spec/AC text to sweep in the same commit**: `EDMV4-T52` AC2/AC3.

---

### CA-080 (P2, L1): The T28 band asserts a count, never distinctness or L1-L14 coverage

**Problem**: `wave8-smoke.sh:4761` cross-checks a lens-file count against `ALL_LENS_IDS`'s count.
Two independently derived numbers that agree is good, but neither asserts that the fourteen declared
IDs are **distinct** and **cover L1 through L14** -- a duplicated or skipped ID passes.

**Fix**: assert the sorted unique ID set equals `L1..L14` exactly, in addition to the count.

**Spec/AC text to sweep in the same commit**: `EDMV4-T28` AC12; `EDMV4-T21`'s `ALL_LENS_IDS` AC.

---

### CA-081 (P2, L2 + L3): A relative `initiative_dir` is re-resolved against the hook's own cwd

**Problem**: `bin/edm-gateguard:112` -- the marker records a relative `initiative_dir` but the
staleness check re-resolves it against the hook process's cwd, so from any other cwd or git worktree
the directory appears missing, the marker reads as stale, and the gate exits 0 (fails open) --
silently disabling the entire gated path.

**Fix**: record an absolute path in the marker, or resolve the relative path against the recorded
project root rather than the process cwd.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC11's stale-marker clause;
`bin/edm-state`'s `_edm_marker_write` format comment.

---

### CA-082 (P2, L3 + L5): `_pattern_record_provenance` -- shared file, fixed-name `.tmp`, wrong lock key

**Problem**: `bin/edm-state:5992` read-modify-writes a shared `harvest-provenance.json` through a
fixed-name (non-`mktemp`, non-`$$`) `.tmp` with no trap, under a lock keyed on a **different** file.
Two audit types interleave and corrupt or lose entries; killed between `jq` and `mv`, the staging file
persists, and no `.gitignore` glob matches the `.tmp` suffix.

**Fix**: key the lock on the provenance file itself, stage through `mktemp "${dest}.tmp.XXXXXX"` with
a four-arm trap, and add the glob to `.gitignore`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T18`'s provenance ACs; the `.gitignore` comment
block enumerating covered runtime-file globs.

---

### CA-083 (P2, L3): `gg_mark_checked` is an unlocked read-modify-write

**Problem**: `bin/edm-gateguard:262` -- two parallel Edit hooks lose one another's checked-path
entry, producing a repeat denial for a file already investigated. With 6-10 parallel agents this is
the common case, not the corner case.

**Fix**: append rather than rewrite (the file is a line list with a 500-entry cap, so an append plus a
periodic compaction is safe), or take the same `mkdir` lock `edm-state` uses.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC6's 500-entry-cap clause, if the
compaction strategy changes.

---

### CA-084 (P2, L3): `gg_record_denial` is unlocked and the budget is keyed per project

**Problem**: `bin/edm-gateguard:283` -- an unlocked read-modify-write, and the denial budget is keyed
per project rather than per session, so 6-10 parallel agents share one 3-denial budget **and**
undercount it through lost updates.

**Fix**: key the budget on the session (the marker already records a session identity) and make the
increment atomic.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC8 and `CLAUDE.md`'s
`EDM_GATEGUARD_MAX_DENIALS` bullet, both of which say "per session" -- currently untrue.

---

### CA-085 (P2, L3): `gg_fresh_lines` `rm -f`s from a separately-read mtime

**Problem**: `bin/edm-gateguard:236` -- a concurrent writer that refreshed the file between the
`stat` and the `rm` has its state deleted.

**Fix**: re-check the mtime immediately before the unlink, or truncate under the same lock CA-083
introduces rather than unlinking.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC6's staleness clause.

---

### CA-086 (P2, L3): The Phase-6 marker is written with a truncating redirect

**Problem**: `bin/edm-state:99` writes the marker with `>` rather than `write_atomic`, so a
concurrent `edm-gateguard` read can observe an empty or torn marker and silently allow the edit.

**Fix**: route the marker write through `write_atomic`, which already exists two hundred lines below.

**Spec/AC text to sweep in the same commit**: `EDMV4-T12`'s marker-write AC.

---

### CA-087 (P2, L3): The mkdir lock's live-holder branch has no age cap

**Problem**: `bin/edm-state:1520` -- a SIGKILLed holder whose PID is later recycled makes the lock
appear permanently live, stalling every mutator on that initiative with no recovery subcommand.

**Fix**: cap the live-holder branch by lockdir mtime age and break the lock past the cap with a loud
diagnostic; add an `edm-state unlock <PREFIX>` escape hatch.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s locking section (CA-415/CA-169 band),
which describes the holder-liveness check.

---

### CA-088 (P2, L3): `write_atomic` references a `local` from its EXIT trap body

**Problem**: `bin/edm-state:722` -- the exact local-in-trap pattern `_harness.sh:79` documents as
broken; the trap body runs after the function's locals are gone. `with_state_lock`'s sibling correctly
uses a non-local.

**Fix**: make `_WRITE_ATOMIC_TMP` non-local, matching the sibling.

**Spec/AC text to sweep in the same commit**: `_harness.sh:79`'s hazard note (cross-reference it from
`write_atomic`).

---

### CA-089 (P2, L3): The completeness check downgrades irreversibly with no re-poll

**Problem**: `bin/edm-state:4983` -- the CA-471 check downgrades a round to `partial` if any of the
14 concurrently-written lens JSONL files has not landed yet, with no re-poll and no repair path. The
downgrade is irreversible for that round.

**Fix**: re-poll with a bounded backoff before downgrading, and provide a repair subcommand for the
case where a file lands after the check.

**Spec/AC text to sweep in the same commit**: `skills/code-audit/SKILL.md:172-182`'s irreversibility
statement; `EDMV4-T23`'s completeness ACs.

---

### CA-090 (P2, L12): The completeness gate accepts any parseable bytes

**Problem**: `bin/edm-state:4983` -- a placeholder `lens-L{N}.jsonl` satisfies the gate, so a round
converges having proved nothing about content.

**Fix**: require at least one object per file carrying the expected `lens` value and a legal `sev`,
not merely parseable bytes.

**Spec/AC text to sweep in the same commit**: `EDMV4-T23`'s completeness ACs; the lens agents' JSONL
schema section, which the check should validate against.

---

### CA-091 (P2, L12): A round with no pass directory closes silently as `round_type=full`

**Problem**: `bin/edm-state:4969` -- the three-way completeness backstop is gated on a pass directory
and manifest existing, with no `else`.

**Fix**: add the `else` -- a round that produced no pass directory is an error, not a full round.

**Spec/AC text to sweep in the same commit**: `EDMV4-T23`'s backstop AC.

---

### CA-092 (P2, L3): `record-partial-verdict`'s lock spin has no backoff or fairness

**Problem**: `bin/edm-state:5388` -- under 6-10 way contention a starved auditor dies on timeout with
no retry, so its PARTIAL never reaches `partial_verdict_map` and archive stops blocking on it. Note
L3 corrected the briefing on the adjacent claim: the close **does** hold the lock across the full
read-modify-write (CA-160); this residual is contention only.

**Fix**: add exponential backoff with jitter and a retry budget; on final failure, exit non-zero
loudly rather than silently dropping the verdict.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s `record-partial-verdict` section and its
`OPEN_PARTIALS` guarantee.

---

### CA-093 (P2, L8 + L3): A NUL byte desynchronizes rule bytes from rule paths

**Problem**: `bin/edm-hookify:213` -- `build_rule_stream` NUL-joins raw rule bytes and jq re-splits,
pairing `$raws[$i]` with `$ps[$i]` positionally. A rule file containing a NUL adds a split element,
so from that index on every rule's content is paired with the **wrong** path: valid enabled rules are
reported as invalid JSON against a neighbour's path, and the misattributed path is what the operator
is told to fix. `:129`'s find-then-cat TOCTOU additionally dies with a misleading "jq evaluation
failed".

**Fix**: reject any rule file containing a NUL before it enters the stream, or count the split
elements against `${#RULE_FILES[@]}` inside the jq program and fail loudly on disagreement. Give the
TOCTOU path its own message.

**Spec/AC text to sweep in the same commit**: `bin/edm-hookify`'s stream-format header comment;
`EDMV4-T43` ACs.

---

### CA-094 (P2, L3): T17 AC2 compares live-state observations from different times and cwds

**Problem**: `wave8-smoke.sh:347` -- two observations of the live EDMV4 state taken at different
times and from different cwds, with every difference attributed to the removed library.

**Fix**: take both observations in one pass from one cwd against a scratch fixture, not the live
state.

**Spec/AC text to sweep in the same commit**: `EDMV4-T17` AC2.

---

### CA-095 (P2, L3): T20/T17-AC9 git-status windows span the live shared worktree

**Problem**: `wave8-smoke.sh:2840` -- any concurrent writer fails the assertion and is misattributed
to the code under test. Shares a root cause with CA-096.

**Fix**: scope the before/after windows to a scratch repository, not the shared worktree.

**Spec/AC text to sweep in the same commit**: `EDMV4-T20` and `EDMV4-T17` AC9;
`EDMV4-T53` AC7's isolation clause.

---

### CA-096 (P2, L4): The suite hard-codes this initiative's live SRD artifact paths

**Problem**: `wave8-smoke.sh:4553` and neighbours pin paths under
`SRD/edm/EDMV4__ecc-integration/`, so the suite fails in any other consuming repository and on
archive of this one.

**Fix**: derive the initiative directory at test time, or build a scratch initiative. The suite must
survive its own subject being archived.

**Spec/AC text to sweep in the same commit**: `EDMV4-T53` AC1's portability claim; `CLAUDE.md`
Sec."Testing changes".

---

### CA-097 (P2, L4): T48 AC1's positive control is a tautology

**Problem**: `wave7-smoke.sh:5630` compares the real list count against `anchor+1` instead of varying
the list, so the control holds for any list.

**Fix**: vary the list -- add and remove an entry in a scratch copy and assert the count moves.

**Spec/AC text to sweep in the same commit**: `EDMV4-T48` AC1.

---

### CA-098 (P2, L4): `grep -c ... || echo 0` yields a two-line value read as a clean zero

**Problem**: `wave8-smoke.sh:2699` -- when `grep -c` outputs `0` and still exits non-zero, the `||`
appends a second `0`, producing `0\n0`. At `:3027` this makes a **missing delta file** read as a
clean zero count.

**Fix**: use `grep -c ... || true` with the count read through `head -1`, or compute with
`grep -c ...; rc=$?` guarded per CA-014. Assert the delta file exists before counting.

**Spec/AC text to sweep in the same commit**: `EDMV4-T57` AC2's delta-resolution contract.

---

### CA-099 (P2, L4): T48 AC4 asserts a generic substring and tests none of its named properties

**Problem**: `wave8-smoke.sh:248` asserts the substring `append a` and tests none of the three
properties its label names.

**Fix**: assert each of the three properties explicitly.

**Spec/AC text to sweep in the same commit**: `EDMV4-T48` AC4.

---

### CA-100 (P2, L5): Harvested pattern files have no gitignore coverage

**Problem**: `bin/_edm-datadir-lib.sh:87` -- the harvested pattern delta and provenance land at
`${CLAUDE_PLUGIN_DATA}/patterns/` with no `.gitignore` coverage. An absolute `CLAUDE_PLUGIN_DATA`
pointing inside any git tree makes both files untracked in that repository.

**Fix**: add the glob to `.gitignore` and document the constraint in the data-directory section.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s `CLAUDE_PLUGIN_DATA` section; the
`.gitignore` comment block.

---

### CA-101 (P2, L5 + L8): Predictable, untrapped, symlink-following temp files in a relocatable dir

**Problem**: `bin/edm-gateguard:261` and `:282` build fully predictable paths from the PID
(`${GG_CHECKED_FILE}.tmp.$$`) and write with a truncating `>` redirect, which follows a symlink, with
no trap. The default location is user-private, but `EDM_GATEGUARD_STATE_DIR`, `CLAUDE_PLUGIN_DATA`
and `XDG_DATA_HOME` all steer it anywhere including a shared `/tmp`, where another local user can
pre-plant a symlink at the predicted name. `bin/edm-state`'s `write_atomic` already uses
`mktemp "${dest}.tmp.XXXXXX"` -- the family standard this file diverges from. No `.gitignore` glob
matches either name.

**Fix**: use `mktemp "${GG_CHECKED_FILE}.tmp.XXXXXX"` (template form -- BSD `mktemp` rejects a suffix
after the X run) at both sites, check the result before writing, and install a four-arm trap. Apply
the same at `edm-state:5992` (CA-082).

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s temp-file convention (the `write_atomic`
family standard); `EDMV4-T15` AC12's state-directory documentation.

---

### CA-102 (P2, L5): Two cases run `update-patterns` into the real host data directory

**Problem**: `wave7-smoke.sh:2352` (`t42_ac9_case`) and `:4575` (`ca476_loud_diagnostic_case`) run
`edm-state update-patterns` with no `CLAUDE_PLUGIN_DATA`/`HOME`/`XDG_DATA_HOME` isolation, creating
`patterns/srd-audit.md` and `patterns/ticket-audit.md` in the real host data directory. The second
case's own positive control 41 lines later **is** isolated, which shows the pattern was known.

**Fix**: wrap both in the same isolation the neighbouring control uses. These are residual
`EDMV4-T57` cases and belong with CA-048's remediation pass.

**Spec/AC text to sweep in the same commit**: `EDMV4-T57` AC5's isolation clause.

---

### CA-103 (P2, L5): The harvested delta is host-global, uncapped and unrotated

**Problem**: `bin/edm-state:6094` -- the delta is host-global rather than project-scoped and grows
monotonically with no cap, rotation or eviction, while being read into agent context at every audit
round. Cost and context pressure both grow without bound, and one project's patterns leak into
another's audits.

**Fix**: scope the delta by project key (the library already computes one), and cap it with
oldest-first eviction plus a recorded ceiling.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s pattern-library section; `EDMV4-T18`'s
delta ACs.

---

### CA-104 (P2, L5 + L7): Five scratch dirs use a third, untrapped idiom

**Problem**: `wave8-smoke.sh:1009` and four siblings create `T27_TMP`, `T56_TMP`, `T50_TMP`,
`T51_TMP` and `T51_PYSCRATCH_DIR` with a bare `mktemp -d`, no trap, and a trailing `rm` that any
signal skips -- a third idiom alongside the file's hand-rolled traps and `harness_scratch_dir`.

**Fix**: converge on one idiom. Once CA-027 makes `harness_scratch_dir` multi-call-safe, route all
five through it.

**Spec/AC text to sweep in the same commit**: `_harness.sh`'s scratch-dir contract comment;
`EDMV4-T53` AC7.

---

### CA-105 (P2, L5): `${data}/run/` accumulates a triple per project key with no sweep

**Problem**: `bin/edm-gateguard:219` -- one `.phase6` + `.checked` + `.denials` triple accumulates
per project key ever used, with no sweep for keys whose project directory no longer exists.

**Fix**: sweep on session start -- remove triples whose recorded project directory is gone, which is
the same liveness test `:112` already performs.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s state-directory layout section.

---

### CA-106 (P2, L7): The only hook consumer on `set -euo pipefail`, uncommented

**Problem**: `bin/edm-gateguard:48` runs `set -euo pipefail`; `edm-hookify`, `edm-stop-gate` and
`edm-bash-gate` all use `set -uo pipefail`, with no comment explaining the split. The difference is
load-bearing -- it is what makes CA-077's unguarded substitutions fatal in this one file.

**Fix**: state the reason in-file, or converge on `set -uo pipefail` once CA-077's guards are in
place.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s hook-consumer family conventions.

---

### CA-107 (P2, L7): `--help` alias sets diverge across the hook-consumer family

**Problem**: `bin/edm-gateguard:69` accepts `-h|--help|help`; the other three accept only
`-h|--help`; and four `bin/` scripts document a narrower set than they accept.

**Fix**: converge on one alias set and make each help block state exactly what it accepts.

**Spec/AC text to sweep in the same commit**: each affected script's `EDM-HELP` block;
`_edm-cli-lib.sh`'s help conventions comment.

---

### CA-108 (P2, L7): Two of four consumers silently ignore every positional argument

**Problem**: `bin/edm-bash-gate:48` and `edm-stop-gate` ignore positionals; `edm-gateguard` dies on
any argument and `edm-hookify` dies on an unknown subcommand. A typo'd flag reads as a normal hook
invocation on two of four.

**Fix**: die on unexpected positionals in both, matching `edm-gateguard`.

**Spec/AC text to sweep in the same commit**: both scripts' `EDM-HELP` blocks; `EDMV4-T46`/`T45`
usage ACs.

---

### CA-109 (P2, L7 + L8 + L10): Three project-root resolvers diverged; the CA-500 check is missing

**Problem**: `bin/edm-state`'s `_resolve_permcheck_project_root` (`:1137-1164`) carries a
physical-path containment cross-check against the git toplevel plus a stderr diagnostic on
disagreement -- the CA-500 hardening. `bin/edm-hookify:106-107` accepts `CLAUDE_PROJECT_DIR` on a
bare `[[ -d ]]` test with no cross-check, and its help text at `:24-25` claims it resolves the root
"the same way `check_permission_rules()` resolves it in `bin/edm-state` (CA-448 baseline)", which is
factually wrong. `_edm-datadir-lib.sh:114-121` (`edm_project_key`) carries the same unchecked pattern
for the Phase-6 marker key. Consequence: one environment variable redirects rule discovery to an
arbitrary directory's `.claude/edm-hookify/*.json`, and that rule set then governs blocking decisions
for the real repository.

**Fix**: extract the containment logic into a shared helper and call it from `edm-hookify` and
`_edm-datadir-lib.sh` -- the library that AD3 already designates as the sole owner of that chain.
Update the stale parity claim either way.

**Spec/AC text to sweep in the same commit**: `bin/edm-hookify:24-25`'s parity claim;
`CLAUDE.md`'s CA-500/CA-448 project-root section; `_edm-datadir-lib.sh`'s AD3 ownership comment.

---

### CA-110 (P2, L7 + L10): The sole lens that hard-wraps the byte-identical house boilerplate

**Problem**: `agents/edm-audit-security.md:19-21` is the only one of fifteen that hard-wraps the
house Scope paragraph, breaking the T28 contract's "byte-identical across every lens" clause -- on
one of the two files `CLAUDE.md` names as verified in full. L10 filed it NOTED as whitespace-only and
explicitly accommodated by the checker; L7 filed it P2 as a contract breach. Multi-lens merge takes
the higher severity: the accommodation is real, but it is exactly what forced CA-069's two-sided grep
and the 44-character hole.

**Fix**: unwrap the paragraph in `edm-audit-security.md` so the contract holds literally, which then
lets CA-069's check become a single exact match rather than a three-grep approximation.

**Spec/AC text to sweep in the same commit**: `EDMV4-T28` AC5; the `:4793` checker comment and the
wrap-tolerance rationale.

---

### CA-111 (P2, L7): The two datadir-lib consumers guard sourcing with different predicates

**Problem**: `bin/edm-gateguard:88` guards with `[[ -f ]]`, `bin/edm-state` with `[[ -r ]]`. A file
that exists but is unreadable aborts the `set -e` gate instead of degrading.

**Fix**: use `[[ -r ]]` in both.

**Spec/AC text to sweep in the same commit**: `_edm-datadir-lib.sh`'s sourcing-contract comment.

---

### CA-112 (P2, L7 + L10): Two hand-rolled "active initiatives" derivations that disagree

**Problem**: `bin/edm-repo-readiness:134` derives active initiatives from
`edm-state list | awk /phase=/`, while `edm-stop-gate` uses the dedicated `active-initiatives`
subcommand. The two sets differ -- phases 0 and 7 are included by one and excluded by the other -- so
the scorecard and the Stop gate disagree about what is active.

**Fix**: have `edm-repo-readiness` call `active-initiatives`. Neither consumer should parse the
human-readable listing.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`'s active-initiative rubric AC;
`CLAUDE.md`'s `active-initiatives` contract.

---

### CA-113 (P2, L8): A rule message reaches `permissionDecisionReason` with no provenance frame

**Problem**: `bin/edm-gateguard:405` -- `emit_decision deny "$GG_HOOKIFY_OUT"` folds a rule author's
own `message`, read verbatim from a working-tree JSON file, into the exact string Claude Code hands
back to the model as the authoritative refusal reason. Nothing labels it as third-party content: to
the model it is indistinguishable from EDM's own four-fact denial text. A repository cloned for
review can inject instructions into the agent's context on the first Edit. T52's sanitizer (`:163`) is
a non-ASCII filter and does nothing about this. The same channel exists at `edm-bash-gate:72` and
`edm-stop-gate:166`. CA-196 records the same class pre-existing in `edm-lint-staged-artifacts`.

**Fix**: wrap third-party text in an unambiguous non-instruction frame naming the rule and its source
path and marking the body as untrusted project text; cap the interpolated length. Keep the rule id
and path so an operator can find and delete the offending file.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s hookify message documentation;
`EDMV4-T44`'s deny-payload AC.

---

### CA-114 (P2, L8): Untrusted Oniguruma pattern with no time bound; the header claim is false

**Problem**: `bin/edm-hookify:205` -- `regex_match` runs the rule author's pattern through jq's
`test()` against up to 65536 characters. The header at `:26-35` claims "Bounding the INPUT bounds the
cost of Oniguruma's `regex_match`"; that is false for catastrophic backtracking, whose cost is
exponential in input length. `"^(a+)+$"` against a few hundred `a` characters hangs. Via
`edm-bash-gate` this wedges every bash command in the session; via `edm-gateguard:401` it wedges every
Edit/Write/MultiEdit. `timeout(1)` was correctly rejected as non-portable and nothing replaced it.

**Fix**: correct the header claim. Bound cost rather than only input: lower the field cap
substantially for `regex_match` specifically, reject patterns with nested quantifiers at validate
time, and/or run the evaluation behind a bash-3.2-compatible `sleep`-plus-`kill` sentinel subshell so
a runaway is killed and reported as a setup error, never as a block.

**Spec/AC text to sweep in the same commit**: `bin/edm-hookify:26-35`'s cost-bounding claim;
`CLAUDE.md`'s `regex_match` documentation.

---

### CA-115 (P2, L8): No kill switch on `edm-bash-gate` or `edm-stop-gate`

**Problem**: `edm-gateguard` ships two documented kill switches checked before anything else runs
(`:80-85`). `edm-bash-gate` -- registered on the `Bash` `PreToolUse` matcher, so it sees and can
refuse **every** bash command -- has none, and neither does `edm-stop-gate`. A broadly-blocking rule
(or CA-114's ReDoS, or CA-029's forged block) leaves an operator with no environment-variable escape:
the only recovery is editing the rule file through tooling the gate may be refusing.

**Fix**: add the same two-switch preamble to both (a shared `EDM_HOOKIFY`/`EDM_HOOKIFY_DISABLED`
pair, or one `EDM_HOOKS_DISABLED`), checked before any `command -v`, and document them alongside the
`EDM_GATEGUARD_*` family.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s "`EDM_GATEGUARD_*` knob family" section,
which currently presents the escape hatch as covering the hook family.

---

### CA-116 (P2, L9): The `MultiEdit` arm shipped against an unmet D26 precondition

**Problem**: `decisions.md` D26 (Spike B, `EDMV4-T07`) closes: "`MultiEdit` remains genuinely
unverified and **should be re-tested before GateGuard's `MultiEdit` arm ships**." No re-test happened
-- D44 closes `T07` `NOT RUNTIME-VERIFIED` -- yet `EDMV4-T11`'s AC requires the
`Edit|Write|MultiEdit` matcher, so the pack and the decision ledger contradict each other on a
shipping precondition. As shipped the arm is inert on this host and harmless; the defect is two
authoritative records disagreeing.

**Fix**: reconcile in one place -- amend D26's closing sentence to record that the arm ships
unverified under `T11`'s AC and is carried by `EDMRT`, or add `MultiEdit`-arm re-verification
explicitly to `EDMRT`'s scope.

**Spec/AC text to sweep in the same commit**: `decisions.md` D26 and D44; `EDMV4-T11`'s matcher AC.

---

### CA-117 (P2, L9): The cross-cutting Changelog AC is unassignable by construction

**Problem**: exactly three tickets list `CHANGELOG.md` in Target Components -- `T01`, `T33` (AC12) and
`T54` (AC9) -- and exactly those three produced `[3.3.0]` content. Every epic-02/03/05/06 ticket
carries the cross-cutting Changelog AC but names no CHANGELOG target, so its implementer could not
satisfy it without writing outside its assigned scope, which D34 records as a contract violation and
correctly praises an implementer for refusing. This is the `T18`/`T20` mutual-assumption pattern on a
second surface, and it is the mechanism behind CA-025. **A cross-cutting AC that no ticket's Target
Components can reach is unassignable by construction, and reads as satisfied because no single ticket
fails on it.**

**Fix**: assign ownership explicitly -- add `CHANGELOG.md` to `EDMV4-T53`'s Target Components (it
already owns the DoD pass and DoD evidence) with an AC naming DoD item 8, or make the CHANGELOG a
coordinator obligation at wave close on the D34 precedent. Record the general lesson as a pattern via
`edm-state update-patterns`.

**Spec/AC text to sweep in the same commit**: `tickets/README.md:69`'s cross-cutting AC list;
`EDMV4-T53`'s Target Components; `decisions.md` D34.

---

### CA-118 (P2, L10): Three byte-identical awk extractors plus a near-variant, none shared

**Problem**: `wave8-smoke.sh:3547` -- `_t44_extract_emit_decision`, `_t13_extract_fn` and
`t51_extract_fn` are byte-identical, with a fourth near-variant nearby.

**Fix**: extract one `_extract_fn_body` into `_harness.sh` and call it from all four.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-119 (P2, L10): Two helpers re-implement `_harness.sh`'s own extract-between

**Problem**: `wave8-smoke.sh:120` -- `_t34_extract_between` and `_t41_extract_between` re-implement
`_harness.sh`'s `_wave7_extract_between`, which the same file already calls at `:5569`.

**Fix**: delete both and call the shared helper.

**Spec/AC text to sweep in the same commit**: n/a.

---

### CA-120 (P2, L10): `metrics-report` reads `.lenses` inline

**Problem**: `bin/edm-state:3804` reads `(.lenses // [])` inline instead of `LENS_READ_JQ_DEF`'s
`read_round_lenses`, so a C-4 legacy full round renders `Lenses=0` against its own caption. CA-199
records the one other inline read as provably equivalent; this one is not.

**Fix**: route through `read_round_lenses`, which exists precisely so the substitution happens in one
place.

**Spec/AC text to sweep in the same commit**: the `LENS_READ_JQ_DEF` comment at `:4755`, which claims
all readers route through it.

---

### CA-121 (P2, L10): Five copy-pasted gate blocks, one already diverged

**Problem**: `hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71` -- five near-identical
`UserPromptExpansion` blocks (a command one-liner plus a roughly 1100-character advisory prompt)
copy-pasted per skill. The `implement` copy has **already diverged** with an extra Gate 3.5 clause.

**Fix**: JSON has no include mechanism (CA-203), so factor the advisory text into a file the command
reads, or generate `hooks.json`'s gate blocks from one source and assert the five are identical
modulo the skill name.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s gate-hook section, which describes the
five as identical.

---

### CA-122 (P2, L11 + L2): `file`-event rules are unreachable outside Phase 6, documented nowhere

**Problem**: `bin/edm-gateguard:101-103` bare-`exit 0`s on marker-absent, **before** the hookify call
site at `:393-406`. So in any repository not currently inside Phase 6 of an EDM initiative -- the
normal state of every adopting project most of the time -- a `file`-event rule with
`"action": "block"` is read by nobody and blocks nothing. The other two events have no such coupling:
`edm-bash-gate:55-74` evaluates `bash` rules unconditionally and `edm-stop-gate:158-168` evaluates
`stop` rules whenever any initiative is active (and documents that scoping at `:154-157`, which is why
CA-209 is NOTED and this is not). L2 filed the marker-absent fast-allow NOTED as by-design; L11 filed
the *asymmetry* P2. Multi-lens merge takes the higher severity -- a rule author reading `CLAUDE.md`'s
per-event field table has no way to know one of three events is silently Phase-6-scoped.

**Fix**: preferred -- hoist the hookify block above the marker early-exit and guard it on the rule
directory existing (`[[ -d "${PROJECT_ROOT}/.claude/edm-hookify" ]]`), so a repo with no rules pays
zero subprocesses and a repo with rules gets them enforced. Minimum acceptable -- document the
scoping at `edm-gateguard:37-38` and in `CLAUDE.md`'s hookify section.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s per-event field table and hookify
section (also CA-123's target); `EDMV4-T45` AC1.

---

### CA-123 (P2, L11): The canonical Hookify section still declares the layer inert

**Problem**: `CLAUDE.md:899-901` states "no evaluator reads these files yet, no subcommand consumes
them, and no hook fires because of them", and `:925-926` says "the plugin ships the format and (in a
later initiative) the reader". As of **this** initiative three shipped consumers read those files and
all three can block: `edm-gateguard:401` (deny at `:405`), `edm-bash-gate:67` (exit 2 at `:73`),
`edm-stop-gate:160` (blocking exit at `:170`). `CLAUDE.md:1093-1095` describes the two-tier exit
contract fewer than 200 lines below the section saying no subcommand consumes the rules. A team
acting on `:899-901` will believe an `"action": "block"` rule is inert and cannot break anything,
then find it denies `Edit` calls and refuses `Stop`.

**Fix**: rewrite `:899-901` and `:925-926` to name the three consumers and their events,
cross-reference the exit contract at `:1093`, and state the Phase-6 scoping of the `file` event
(CA-122).

**Spec/AC text to sweep in the same commit**: `EDMV4-T43`/`T45`'s documentation ACs; `CHANGELOG.md`
(the rules layer becoming live is a user-visible change -- folds into CA-025).

---

### CA-124 (P2, L12): The pattern-library seed path is never checked non-empty

**Problem**: `skills/srd/SKILL.md:169` and three sibling call sites take the seed path from
`get-patterns | sed -n '1p'` and never check it non-empty, so a failed resolution silently produces
an ungrounded SRD, ticket pack or coverage report.

**Fix**: check non-empty at all four sites and refuse with a named diagnostic rather than proceeding
ungrounded.

**Spec/AC text to sweep in the same commit**: `CLAUDE.md`'s pattern-library section, which states the
seed is always available.

---

### CA-125 (P2, L12): A missing `canonical-sections.md` makes the check silently not run

**Problem**: `bin/edm-check-grants:656` wraps the citation-orphan check in
`if [[ -f "$CANON_DOC" ]]` with no `else`, so a missing `docs/canonical-sections.md` makes the whole
check silently not run and exit 0 clean. Combined with CA-078, this check has two independent ways to
report clean while checking nothing.

**Fix**: add the `else` -- a missing canonical document is a setup error, not a pass.

**Spec/AC text to sweep in the same commit**: `EDMV4-T04` AC11; `CLAUDE.md`'s by-name-reference
section, which treats `canonical-sections.md` as always present.

---

### CA-126 (P2, L12): An aborting gateguard still prints `budget_status=MET`

**Problem**: `bin/tests/timing.sh:475` -- `--gateguard` measures through `_measure_p95`'s `|| true`
with no correctness probe, so a gateguard that aborts on every call measures fast and reports MET.
CA-212 records that this mode is manual-only by design, which bounds the impact but not the
wrongness.

**Fix**: assert a known-good decision on at least one sampled call before reporting a budget verdict.

**Spec/AC text to sweep in the same commit**: SRD Sec.9.1/9.3's allow-path budget; the D34 figure's
provenance note (CA-144).

---

### CA-127 (P2, L14): `EDM_GATEGUARD_MAX_DENIALS` is never set by any test

**Problem**: only the hardcoded default of 3 is exercised (T15 AC8, `wave8-smoke.sh:4460-4474`), so
the env-reading half of the documented knob is unverified -- misspelling the variable name in the
script would leave every assertion green.

**Fix**: re-run the AC8 four-path loop with `EDM_GATEGUARD_MAX_DENIALS=1` asserting the rc sequence
becomes `2 0 0 0`, and once with `0` to pin the budget-already-spent boundary. CA-009's validation
case belongs here too.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC8/AC12.

---

### CA-128 (P2, L14): Rubric signals only observed at this repository's current values

**Problem**: `bin/edm-repo-readiness:172` -- `_rr_any_other_blocking_anomaly` returns false here and
is never driven true; `CH_CALIBRATION_AVAILABLE`, `CH_COST_HISTORY` and `_rr_archived_count` are all
true here and never driven false. The only score assertion (`wave8-smoke.sh:3167-3182`) re-derives
the mean from the script's own reported category scores -- **a self-consistency identity that holds
for any values, including a grep that never matches.**

**Fix**: add one scratch fixture per signal (a `TIME_ORDER`-class blocking anomaly, an archive count
of 0, a state with no recorded cost) asserting the named check's `pass` flips and its category's
`raw_earned` drops by that check's declared `points`.

**Spec/AC text to sweep in the same commit**: `EDMV4-T38`/`T40`'s rubric ACs.

---

### CA-129 (P2, L14): `edm-hookify list` is invoked once with output discarded

**Problem**: `wave8-smoke.sh:2076` is the only invocation and it redirects to `/dev/null` inside the
writes-no-files snapshot. Nothing covers what `list` prints: the one-name-per-line contract, the
`$parsed.name // $path` fallback, or the omission of `enabled:false` rules. CA-056's defect lives on
exactly this path.

**Fix**: add three assertions against the existing `T43_PROJ` rule directory -- the exact set of names
printed, one line per enabled rule, and a disabled rule's absence.

**Spec/AC text to sweep in the same commit**: `bin/edm-hookify`'s `EDM-HELP` block description of
`list`.

---

### CA-130 (P2, L14): Only one of `MultiEdit`'s two tolerated payload shapes is driven

**Problem**: `bin/edm-gateguard:375` is deliberately tolerant of two shapes, but T14 AC4/AC5
(`wave8-smoke.sh:4131-4177`) use `edits[].file_path` exclusively. Claude Code's own single-file shape
-- the one the code comment says the tolerance exists for -- has no test, nor does the `unique`
de-duplication when both appear together.

**Fix**: add the single-file shape (assert the denial names `tool_input.file_path`) and a mixed
payload where `tool_input.file_path` duplicates one `edits[].file_path` (assert three denials for
three distinct paths, not four).

**Spec/AC text to sweep in the same commit**: `EDMV4-T14` AC4; the tolerance comment at `:375`;
`decisions.md` D26 (CA-116, same arm).

---

### CA-131 (P2, L14): `gg_is_exempt` is only driven with a single-entry glob value

**Problem**: only `**/tests/**` (T15 AC4) and the shipped default (AC5) are ever used. Untested: a
multi-entry comma list (which exercises the `IFS=,` split, the array build and the empty-element
`continue` at `:303-304`), a glob written without the `**` prefix (which exercises the `stripped`
second attempt at `:309-312`), and an explicitly-empty value, which `${VAR:-default}` silently
converts back into the full default list rather than exempting nothing.

**Fix**: add a three-entry comma list with one empty element (assert two of three exempt, one
denied), a bare `src/generated/*` glob, and `EDM_GATEGUARD_EXEMPT_GLOBS=""` asserting whichever
behaviour is intended -- and state which that is. CA-073's `set -f` fix needs these cases to prove it.

**Spec/AC text to sweep in the same commit**: `EDMV4-T15` AC4/AC5; `CLAUDE.md`'s
`EDM_GATEGUARD_EXEMPT_GLOBS` bullet, which does not state the empty-value behaviour.

---

### CA-132 (P2, L14): The per-prefix validate-died branch is untested

**Problem**: `bin/edm-stop-gate:120` -- T46 AC9's two internal-error cases both fail
`active-initiatives` and `soft_exit` before the loop is reached, so the
`case "$_validate_rc" in 0|3) ;; *) continue ;;` arm is never driven. That arm is what guarantees a
single broken initiative never blocks Stop and never suppresses its healthy siblings.

**Fix**: add a two-initiative fixture where one prefix's state file is corrupted so `validate` exits
with a setup code, asserting the gate still reports the other prefix's anomalies and exits on the
other prefix's verdict alone. CA-040's diagnostic is asserted here.

**Spec/AC text to sweep in the same commit**: `EDMV4-T46` AC9.

---

### CA-133 (P2, QC-W05): T53 AC10 -- the five DoD command results are recorded nowhere

**Problem**: AC10 requires the five commands to be "run and each result recorded". Grepping
`decisions.md`, `HANDOFF.md` and `qc/` for `edm-check-skill-sync`,
`sync-canonical-sections --check` and `plugin validate` returns no result record. Only DoD item 2 is
recorded, in commit `6386a52`'s body. **Wave-5 QC executed all five and all pass**:
`edm-check-grants` 0, `edm-check-vocabulary` 0, `edm-check-skill-sync` 0,
`edm-sync-canonical-sections --check` 0, and `claude plugin validate plugins/edm/` reports
"Validation passed with warnings" (one warning, the known "CLAUDE.md at the plugin root is not loaded
as project context"). The substance holds; the record did not exist until that report.

**Fix**: fold the five results into `decisions.md` as the DoD item 3/item 4 evidence entry, alongside
D43.

**Spec/AC text to sweep in the same commit**: `EDMV4-T53` AC10; `srd.md` Sec.3.4 DoD items 3-4.

---

## Decisions / Non-Findings

These 81 items were flagged by one or more lenses and determined to be Not Actionable, or were
demoted by the Second-Pass False Alarm Filter. **None was deleted** -- each carries a ledger line at
`sev: "NOTED"` / `status: "noted"`. Future audits should NOT re-investigate them.

Four adjudications and two corrections shaped this round and are recorded first, because they change
what a later reader should believe:

1. **`EDM_GATEGUARD_MAX_DENIALS` (CA-009)** -- L12's NOTED ("loud `unbound variable` abort under
   `set -u`") is wrong: `set -u` fires on an unset variable, not one set to a non-numeric string.
   Orchestrator-adjudicated for L1's P1. L12's framing is not carried as a competing ledger line.
2. **The `git commit` matcher (CA-007)** -- L2's em-dash corroboration is invalid and was dropped;
   the surviving em dashes are fully explained by the hook's documented prefix-mode reach. The
   finding stands on the tool-name evidence alone.
3. **`stat -f` in the T43 AC9 snapshot (CA-053)** -- L4 and L14 both demoted this to NOTED because
   the paired positive control surfaces the vacuity. Wave-5 QC executed it and showed the control
   detects only a change in file *count*, not the modification the check exists to catch. Retained
   at P1; both NOTED views are superseded rather than recorded separately.
4. **`wave7`'s SIGINT case (CA-161)** -- L3 corrected the orchestrator's briefing, not the reverse.
   The `|| true` guard swallows the failed `kill`, not the verdict: when the signal misses, both
   assertions FAIL loudly. The real defect is narrower (the case is only green where a controlling
   terminal exists) and `harness-smoke.sh`'s sibling (CA-018) genuinely does pass silently.
5. **`T45`'s "no rule file ships" (CA-136)** -- corrected by wave-4 QC. This is the specification,
   not a defect: `.claude/edm-hookify/` is project-owned and `wave8-smoke.sh:830-832` asserts
   affirmatively that no default rule file may ship. The auditor ran all four cases in a scratch
   project and confirmed an enabled `block` rule produces a real deny payload, so the blocking path
   is reachable by exactly the configuration the format documents.
6. **`T57`'s `NEEDS-NEW-TICKET` comments (CA-062)** -- corrected by wave-4 QC. The two comments
   annotate assertions that **currently pass**; the auditor re-derived the four-heading contract by
   hand over all five `docs/audit-patterns/*.md` files. AC6 is met at tip. They are stale comments,
   not AC violations, and are recorded at P2 rather than L9's P1.

**Coverage caveat**: the full statement of what this round did not look at is in `## Context` above
and is not repeated here. In brief: L1 had no `Bash` tool and located code by `EDMV4-T##` markers, so
unmarked edits to pre-existing code were missed; L4 grepped rather than read `wave3`, `wave4a`,
`wave4b` and `wave5`; L6 did not sweep `edm-state`'s full message surface; L9 did not check "no new
linter warnings"; L10 had no `Bash` grant. Every lens also hit its `maxTurns: 30` ceiling at least
once against this diff and required resumption.

Demoted by the filter (single lens, low confidence, no corroborating evidence):

1. **CA-134 (L3)** `edm-state:1599` lock release `rm -rf`s by path without a pidfile check -- low
   confidence, single lens.
2. **CA-158 (L3)** `write_atomic` does not `fsync` before `mv -f` -- low confidence; regenerable
   artifacts and a `.bak` sibling mitigate.

Not Actionable (documented as intentional, pre-existing, or an accepted trade-off):

3. **CA-135 (QC-W04)** T45 AC9's `run-all.sh` clause is a recorded PARTIAL; closes via
   `/edm:verify-runtime`, not remediation.
4. **CA-137 (QC-W05)** T50 AC4's word-membership idiom cannot express the glob match the constant
   needs -- justified deviation.
5. **CA-138 (QC-W05)** T51 AC6's `find` excludes `evals/fixtures/`; `tiny-svc` predates EDMV4 and is
   the subject under evaluation.
6. **CA-139 (QC-W05)** T53's `CLAUDE.md` `bin/`-table row is correct but unscoped -- delivered but
   ungraded, recorded so it is not mistaken for AC coverage.
7. **CA-140 (L1)** `CITATION_EXEMPT_SECTIONS` space-joined idiom -- correct for the one entry that
   exists, breaks on the second.
8. **CA-141 (L1)** Bare `Sec.` continuation undetected -- documented at the check and in D32.
9. **CA-142 (L1)** Completeness check (3) unreachable for a legacy full round -- the specified
   AC10(a) C-4 behaviour.
10. **CA-143 (L1)** `pattern_seed_file_for` has no default arm -- unreachable; both call sites
    validate the enum first.
11. **CA-144 (L1)** `timing.sh --gateguard` branch 2 measures a heterogeneous sample -- that is what
    the D34 figure records.
12. **CA-145 (L1)** `edm_data_dir` resolves `/.local/share/edm` for a root caller with `HOME` unset;
    non-root gets the intended degradation.
13. **CA-146 (L2)** The `MultiEdit` dispatch arm is unreachable on this host (D26) but is documented
    restraint, exercised by fixtures.
14. **CA-147 (L2)** L13's own N/A exit is unreachable -- a deliberate agreement clause with
    code-audit Step 1.
15. **CA-148 (L2)** `emit_decision`'s unknown-decision arm is unreachable; all three call sites pass
    a literal.
16. **CA-149 (L2)** `declare -F` guards cannot be false; line 93 already required the last-defined
    library function.
17. **CA-150 (L2)** `op_match`'s terminal `else false` is preempted but required for jq
    if-without-else correctness.
18. **CA-151 (L2)** Three unreachable defensive arms in the jq scorer.
19. **CA-152 (L2)** `detect-conditional-lenses`' no-predicate `die` arm cannot fire -- kept as a
    growth tripwire.
20. **CA-153 (L2)** `op_match` is unreachable for the fieldless `stop` event by construction.
21. **CA-154 (L3)** `PAYLOAD_RAW=$(cat)` blocks with no stdin, but every in-repo caller pipes
    explicitly.
22. **CA-155 (L3)** `update-patterns`' insertion-line TOCTOU is real but documented (G16/CA-355) and
    dies loudly.
23. **CA-156 (L3)** The `flock` branch installs no cleanup trap -- correct by construction; CA-169
    forbids unlinking.
24. **CA-157 (L3)** The two parallel Stop hooks cannot produce a torn read -- one snapshot, atomic
    `mv`.
25. **CA-159 (L3)** `_EDM_TRAP_DEPTH` is process-global, documented with a verified call-graph
    sweep.
26. **CA-160 (L3)** `record-partial-verdict` holds the lock across the full read-modify-write; the
    check-then-lock race is closed per CA-059.
27. **CA-161 (L3+L4)** wave7's SIGINT case is tty-dependent but fails loudly -- test-environment
    robustness, not a live defect.
28. **CA-162 (L4+L9)** `edm-gateguard`'s 413 lines against T11 AC1's band -- D42 raised the ceiling
    with rationale after a properly escalated refusal.
29. **CA-163 (L4)** wave6 T23 AC4 pins an unverifiable citation, accurate against the current tree.
30. **CA-164 (L4)** Precondition guards `fail` but never `pass`, so the assertion total is
    asymmetric between healthy and broken runs.
31. **CA-165 (L4)** `awk -v` marker escape handling verified CORRECT -- recorded so it is not
    re-flagged.
32. **CA-166 (L5)** T25 AC9's grants capture already writes into a trapped scratch dir -- the
    reference fix for CA-020's class.
33. **CA-167 (L5)** `edm-hookify` creates no temp files at all -- no runtime-file surface to
    gitignore.
34. **CA-168 (L5)** Parallel-agent worktrees are covered by the repo-root `.gitignore`.
35. **CA-169 (L5)** `write_atomic`'s staging path is `mktemp`-unique, four-arm trapped and
    gitignored.
36. **CA-170 (L5)** `edm-repo-readiness` writes only its caller-supplied `--json` report.
37. **CA-171 (L5)** No hook body in the manifest creates a runtime file.
38. **CA-172 (L5)** `edm-check-grants`' `WORKDIR` is correct by this codebase's own convention.
39. **CA-173 (L5)** All three `evals/` staging sites are four-arm trapped and TMPDIR-honoring.
40. **CA-174 (L6)** The audit-patterns README 11-lens row is a dated EDMV2-seed snapshot (D33).
41. **CA-175 (L6)** wave7's "eleven lens" phrasing is an EDMV3-era batch-scope note; the assertion
    covers fourteen.
42. **CA-176 (L6)** Pre-3.3.0 CHANGELOG entries are historical records, never edited by policy.
43. **CA-177 (L6)** `ecc-integration-analysis.md`'s "EDM runs 11 lenses" is its stated baseline.
44. **CA-178 (L6)** `edm-explorer.md`'s `generate.ts` citation is external and unverifiable (D12).
45. **CA-179 (L6)** The T56 plugin-distribution section verified against the filesystem.
46. **CA-180 (L6)** The "eleven touch points" count is unrelated to the lens count.
47. **CA-181 (L7+L10)** CA-529 re-verified: all fifteen lens frontmatter blocks are byte-identical.
48. **CA-182 (L7)** `edm-bash-gate` emits no diagnostic on its five bail-outs -- plausibly deliberate
    on a per-Bash-call hook.
49. **CA-183 (L7)** The two hook-body guard idioms track the advisory/blocking split exactly.
50. **CA-184 (L7+L10)** The per-script two-argument `die()` is a deliberate family convention: 2
    already means block on a hook consumer.
51. **CA-185 (L7)** `declare -f` versus `declare -F` is a style-only divergence.
52. **CA-186 (L8)** `flock` on fd 200 is documented (CA-415); bash 3.2 has no dynamic-fd idiom.
53. **CA-187 (L8)** `md5sum` is an artifact-drift checksum, never a security primitive.
54. **CA-188 (L8)** `grep -qP` is a documented, guarded PCRE probe with a BRE fallback.
55. **CA-189 (L8)** `stat -c %Y` with a `stat -f %m` fallback is the sanctioned portable pair.
56. **CA-190 (L8)** `_edm-cli-lib.sh`'s header cites a `.gitlab-ci.yml` job that no longer exists;
    the duplication it guarded is inert.
57. **CA-191 (L8)** `hooks.json`'s `echo` of `$ARGUMENTS` is quoted and immediately clamped.
58. **CA-192 (L8)** The lock-timeout marker is already hardened by G17/CA-305 and G13/CA-347.
59. **CA-193 (L8)** A symlinked rule directory yields zero rules -- fails in the safe direction.
60. **CA-194 (L8)** `EDM_EVAL_MAX_BUDGET_USD` is documented as deliberately unvalidated; outside
    this diff.
61. **CA-195 (L8)** Security categories genuinely inapplicable to this target (systemd, containers,
    CORS, SQL, SSRF, credentials, TLS, dependency pinning).
62. **CA-196 (L8)** `edm-lint-staged-artifacts` relays repository content into a refusal -- same
    class as CA-113 but pre-existing (CA-436).
63. **CA-197 (L9)** `SRD/.codemap.md` is absent; every T48 AC binds the instruction, not the
    artifact, and all nine are satisfied.
64. **CA-198 (L9)** The six D44 tickets verified static-clean -- recorded so "verified" is
    distinguishable from "never checked".
65. **CA-199 (L10)** `cmd_audit_converged` reads `.lenses` inline where the two forms are provably
    equivalent.
66. **CA-200 (L10)** CA-005 verified clean: every `--help` site sources the shared `print_help`.
67. **CA-201 (L10)** CA-513 verified clean: no fourth hand-rolled fence tracker.
68. **CA-202 (L10)** The `usage()` wrapper cannot be factored -- `BASH_SOURCE[0]` resolves to the
    library.
69. **CA-203 (L10)** The `command -v` guard idiom repeats because JSON has no include mechanism.
70. **CA-204 (L10)** `_rr_archived_count` duplicates layout knowledge; the cause is recorded at the
    site.
71. **CA-205 (L10)** The stdin payload-read triplet diverges for a documented reason.
72. **CA-206 (L10)** The JSONL schema line is repeated in all 14 lens agents by design (D22/CA-130).
73. **CA-207 (L11)** `edm-repo-readiness --json` has no shipped consumer -- a documented CLI
    affordance, and the acquisition path CA-034 should use.
74. **CA-208 (L11)** `edm-hookify list` has no in-plugin consumer -- a documented CLI surface.
75. **CA-209 (L11)** stop-event rules are scoped to active initiatives, documented at `:154-157`
    with a stated rationale (unlike CA-122).
76. **CA-210 (L12)** The `command -v` guards make each hook a documented, deliberate silent no-op.
77. **CA-211 (L14)** Withdrawn: the hookify deny path IS driven end to end by T52 AC7b.
78. **CA-212 (L14)** The 50 ms gateguard budget is measured only by a manual `timing.sh` mode --
    matching every other mode's precedent.
79. **CA-213 (L14)** `edm_project_key`'s terminal `pwd` fallback is untested but has no branching of
    its own.
80. **CA-214 (L14)** `edm-repo-readiness`'s `--json` write-failure `die` is untested; no state to
    corrupt.
81. **CA-136 (L2+L11+QC-W04)** No hookify rule file ships -- the specification, not a defect; see
    correction 5 above.

## Rollout Order

**This round does not converge, and no gate should be approved until wave 1 below is complete.**
`edm-state audit-converged EDMV4` will refuse on the open P0/P1 set, and that refusal is correct on
the evidence: all four Definition-of-Done tickets FAILed under the two commissioned QC shards,
`EDMV4-T15` AC7 is inverted with its own smoke test retrofitted to assert the implementation rather
than the criterion, and the three new lens agents may not load at all -- which means this round's own
lens set cannot be assumed complete. `--accept-p2-debt` does not apply: the blocking set is P0 and
P1, and that flag never waives either.

**Wave 1 -- blocks convergence; nothing else starts until these land.** File-independent, so all
five can be parallelized.

1. **CA-002** (`.claude-plugin/marketplace.json`) -- do this first and alone. Until it is settled,
   every other conclusion in this document rests on a lens set that may have been three lenses short.
   Prefer `"agents": ["./agents/"]`. Ten minutes of work.
2. **CA-001** (`bin/edm-gateguard`, `wave8-smoke.sh`) -- the AC7 inversion, its unbounded denial
   loop, the missing `gg_record_denial` advisory, and the inverted test. One commit; the test
   inversion must land with the code or the next round re-derives the same finding.
3. **CA-003** (`bin/edm-stop-gate`) -- `stop_hook_active`. This initiative currently carries an
   `OPEN_PARTIALS` anomaly, so the non-adversarial trigger is live, not hypothetical.
4. **CA-004** + **CA-005** + **CA-063** (`wave8-smoke.sh`, three ticket ACs) -- one commit: give
   `edm-bash-gate` its six behavioural cases, add T50 AC1's membership assertion, and amend the three
   enumerations that exclude `edm-bash-gate` so the two coverage gaps cannot silently reopen.
5. **CA-006** -- commission the shard covering `T11`, `T39`, `T40`, `T54`, `T55`. Run this in
   parallel with 1-4; its findings feed wave 2, and until it lands five tickets remain
   unverified-and-unrecorded, which is the same silent-absence state that produced this section.

**Wave 2 -- the Definition-of-Done pass cannot be re-declared until these land.** Batch by file.

6. Test-integrity batch (`wave8-smoke.sh`, `harness-smoke.sh`, `_harness.sh`): CA-011 through
   CA-020, CA-027, CA-049 through CA-055, CA-057. These are the assertions that cannot fail plus the
   sweeps that exclude the files they were written to protect. **Do this before re-running the suite
   for evidence**, or the re-run inherits the same weak signal.
7. Hookify-safety batch (`bin/edm-hookify`, `bin/edm-bash-gate`): CA-029, CA-030, CA-031, CA-039,
   CA-041, CA-042, CA-043, CA-056. The forge, the isolation break, the payload degradation and their
   missing coverage all touch one file.
8. Readiness-scorer batch (`bin/edm-repo-readiness`): CA-036, CA-037, CA-038, CA-046, CA-047. All
   five are "a read failure scores as success" or its untested twin.
9. Wiring and grants batch: CA-007, CA-008, CA-010, CA-033, CA-034, CA-035, CA-040, CA-044, CA-045.
10. Documentation-truth batch (one commit, because CA-416's stale-citation class recurred five
    consecutive rounds precisely because code fixes landed without the prose sweep): CA-021 through
    CA-026, CA-028, CA-032, CA-058, CA-133. Every one of these is a spec-sweep obligation in its own
    right; landing them together is what makes the `spec_swept` field on the earlier waves honest.

**Wave 3 -- P2s (CA-059 through CA-133).** Remediate before convergence; batch into follow-up
commits by file. Three sub-batches carry more weight than the rest and should not be deferred past
the second round: the GateGuard concurrency and temp-file set (CA-073, CA-083, CA-084, CA-085,
CA-101), the security set (CA-109, CA-113, CA-114, CA-115), and the completeness-gate set (CA-089,
CA-090, CA-091), which governs whether a future round can converge on incomplete evidence.

## Verification Plan

**Standing caveat on the existing evidence.** `run-all.sh` currently reports **3241 passed, 0 failed
across 8 suites**, verified twice consecutively on a quiet tree. **This round demonstrated that
figure is weak evidence.** Four of those assertions cannot fail (CA-011 through CA-015), thirteen
more accept any number where they claim to require zero (CA-016), two are vacuous on the primary
platform (CA-017, CA-053), and eleven `set -e` aborts during this initiative ended a suite with no
failing assertion at all. A green `run-all.sh` is not a convergence argument until wave 2 item 6 has
landed. Re-run it **after** that batch, and record the interpreter alongside the aggregate (CA-058).

Per-blocking-fix proof:

- **CA-002**: `jq '.plugins[] | select(.name=="edm") | .agents' .claude-plugin/marketplace.json`
  reconciles against `ls plugins/edm/agents/*.md`; the new live-glob-versus-manifest assertion fails
  when any agent file is removed from the manifest. Then **re-run the full audit round** -- this
  round's lens set is only trustworthy once this is settled.
- **CA-001**: scratch project, marker present, `run/` at mode 555, same path six times -- every call
  after the first must exit 0 with empty stdout and the `EDM_GATEGUARD_STATE_DIR` warning on stderr.
  Today all six return `rc=2`. Paired control: the identical fixture with a writable `run/` must
  still deny.
- **CA-003**: drive the gate with a blocking anomaly present, once with `stop_hook_active: false`
  (expect exit 2) and once with `true` (expect exit 0, silent); plus missing-`jq` and
  unparseable-payload cases asserting exit 0.
- **CA-004**: six cases through the real `edm-bash-gate` (block, non-match, warn, malformed rule,
  empty stdin, unparseable stdin). Delete the `exit 2` line from a scratch copy and confirm case 1
  fails.
- **CA-005**: move a scratch copy of a named `bin/` file into `bin/subdir/` and confirm the new
  membership assertion fails naming it.
- **CA-006**: `ls SRD/edm/EDMV4__ecc-integration/qc/` shows a shard per wave; `qc-summary.md`'s
  sentinel reads `tickets=55`.

Suite-level, after each wave:

- Syntax: `/bin/bash -n` over every file in `plugins/edm/bin/` (maxdepth 1) and `bin/tests/`;
  `jq -e . plugins/edm/hooks/hooks.json .claude-plugin/marketplace.json
  plugins/edm/.claude-plugin/plugin.json`.
- Static gates: `bash plugins/edm/bin/edm-check-grants`,
  `bash plugins/edm/bin/edm-check-vocabulary`, `bash plugins/edm/bin/edm-check-skill-sync`,
  `bash plugins/edm/bin/edm-sync-canonical-sections --check`,
  `claude plugin validate plugins/edm/` -- all five, with results recorded in `decisions.md`
  (CA-133).
- Suites: `/bin/bash plugins/edm/bin/tests/run-all.sh`, recording the aggregate **and**
  `/bin/bash --version` together (CA-058 AC8).
- Isolation: snapshot `git status --porcelain`, run `wave8-smoke.sh` **in isolation** (not via
  `run-all.sh`, whose pass through `wave6-smoke.sh:4087-4099` deliberately mutates
  `docs/canonical-sections.md`), snapshot again, assert nothing new is attributable to it
  (CA-058 AC7, CA-020, CA-027).
- Runtime-unverifiable items: CA-007's matcher reachability cannot be settled from the working tree
  (`EDMV4-62`). Push the branch, confirm against host `2.1.246`, and record the result in
  `decisions.md` alongside the six D44 tickets. Do not mark CA-007 `fixed` with
  `spec_swept: "yes"` until that observation exists.
- Re-audit (targeted): once wave 1 lands, re-run **L1, L3, L4, L5, L6, L7, L8, L9, L11, L12, L14**
  -- every lens that surfaced a fixed finding. L2 and L10 may be omitted only if no finding they
  contributed to has changed. Note that a targeted re-run is a **partial** round and cannot satisfy
  the convergence gate; a full 14-lens round is required for that, and it must be run **after**
  CA-002 so that all fourteen agents are loadable.
