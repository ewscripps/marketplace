# VERIF -- Verifier truncation and budget parity

Input document for fix-pack ticket generation. Target release: **EDM 3.2.1 -> 3.2.2** (patch: bug
fix, no methodology change).

## The defect, in two parts

### Part 1 -- a truncated verifier is silent, and its partial output is consumed as complete

Every read-only verifier agent can stop at its `maxTurns` ceiling mid-audit. Nothing in the plugin
detects this. The consumer treats whatever was produced as a finished result.

The dangerous instance is **`edm-qc-auditor`**, because no human observes it:

- It is auto-spawned by the `SubagentStop` hook matching `edm-implementer`
  (`hooks/hooks.json:111-121`).
- It writes a verdict shard to `qc/qc-shard-impl-{NN}.md` or `qc/qc-shard-pass-w{WW}-{NN}.md`.
- `/edm:implement` merges every shard into `qc/qc-summary.md` after the wave drains
  (`skills/implement/SKILL.md:39`, `:96-98`).
- **Nothing checks whether a shard is complete.** A shard truncated at turn 25 is merged exactly
  like a finished one.

The consequence is a false PASS: a ticket can be recorded as passing because the auditor ran out of
turns before reaching its acceptance criteria, not because the criteria were met. QC is the gate
that decides whether Phase 6 work is done, so a silent partial there is the highest-consequence
silent failure in the methodology.

`edm-srd-auditor` and `edm-ticket-auditor` fail more visibly -- they return text to an orchestrating
skill, which can notice and resume -- but neither skill is instructed to check, so the same
consumed-as-complete hazard exists on those paths.

**This is precisely the finding class L12 (Silent Failures) is being added to catch in EDMV4: a
fallback that succeeds while hiding a failure. EDM cannot currently see it because it does not yet
have that lens.**

### Part 2 -- verifiers are budgeted below the producers they check

`maxTurns` across the agent set:

| Role | Agents | maxTurns |
|---|---|---|
| Producer | `edm-implementer` | 60 |
| Producer | `edm-srd-writer`, `edm-ticket-writer`, `edm-architect` | 50 |
| Analysis | 11 code-audit lenses, `edm-explorer`, `edm-test-planner`, `edm-test-scaffold` | 30 |
| **Verifier** | `edm-srd-auditor`, `edm-ticket-auditor`, `edm-qc-auditor`, `edm-test-coverage-auditor` | **25** |

All four read-only verifiers sit at the plugin's floor -- 2 to 2.4x below the producers whose output
they check, despite verification being strictly more work: the verifier must read the artifact **and**
cross-reference it against the codebase.

**Provenance: this is not a v3 regression.** `maxTurns: 25` on `edm-srd-auditor` was set once, in
`fe5d0f0` (the `edm-ai-development` -> `edm` rename), and never changed -- git shows one `+maxTurns:
25` and zero removals across the file's history. What v3 did was write scaling guidance that only
scales one side:

- `skills/srd/SKILL.md:84` targets "800+ lines major" for an SRD.
- `skills/srd/SKILL.md:186` says "For large SRDs, run **multiple** `edm-srd-writer` agents in
  parallel".
- `skills/audit-srd/SKILL.md:43` caps the audit at "**2-3** `edm-srd-auditor` agents".

Production scales; verification is hard-capped. v3 did not change the number -- it created a
document-size target the untouched number cannot service.

### Evidence

Observed directly during EDMV4 Phase 3, on a 2,772-line SRD:

- All three `edm-srd-auditor` agents hit the 25-turn ceiling at 45-55 tool uses each, **before
  emitting a single finding**. All three required a resume message to produce any output.
- The `edm-srd-writer` remediation agent hit its 50-turn ceiling **twice**, once mid-edit, leaving a
  requirement half-merged: its body converted to a merged pointer while its dependency line still
  declared the cycle the merge existed to remove. A consistency check caught it; nothing in the
  plugin would have.
- Four cap events in one phase.

## Fix 1 -- completion sentinel (do this first)

**Contract**: every verifier ends its output with a self-describing sentinel, and the consumer
refuses input that lacks it.

For `edm-qc-auditor`, whose output is a file, the last line of the shard:

```
<!-- QC-SHARD-COMPLETE range=T01-T08 audited=8 -->
```

`/edm:implement`'s merge step checks every shard before merging:

```bash
for shard in "${QC_DIR}"/qc-shard-*.md; do
  tail -1 "$shard" | grep -q '^<!-- QC-SHARD-COMPLETE ' \
    || die "qc: ${shard} has no completion sentinel -- auditor truncated; re-run before merging"
done
```

Two properties this design depends on:

1. **`tail -1` is the whole check.** A truncated agent stops mid-sentence and cannot emit a trailing
   line it never reached. No host-behaviour parsing, no new binary, nothing beyond the existing
   `bash`/`jq`/`git` contract.
2. **`audited=` against `range=` catches the subtler failure.** An auditor can terminate cleanly
   having covered six of eight assigned tickets. Completion alone misses that; comparing the count
   against the assigned range catches it. This turns "did it finish" into "did it cover what was
   assigned", which is the property that actually matters.

`edm-srd-auditor` and `edm-ticket-auditor` return text rather than writing a file, so the sentinel
terminates the returned findings and the compiling step in `skills/audit-srd/SKILL.md` /
`skills/audit-tickets/SKILL.md` checks for it. `edm-test-coverage-auditor` writes
`test-coverage.md`, so it uses the file form.

**Negative test required**: a shard with the sentinel stripped must make the merge refuse. A fix
whose failure path is untested is the same class of defect as the one being fixed.

## Fix 2 -- budget parity

Raise `maxTurns` from `25` to `50` on the four verifiers, bringing them to parity with the writers
they check:

- `agents/edm-srd-auditor.md`
- `agents/edm-ticket-auditor.md`
- `agents/edm-qc-auditor.md`
- `agents/edm-test-coverage-auditor.md`

Sizing evidence: the EDMV4 auditors logged roughly 2 tool calls per turn, so 50 turns is
approximately 90-110 tool calls -- which comfortably covered the work once they were resumed.

**Ordering matters: Fix 1 lands before Fix 2.** A higher budget reduces how often truncation
happens but never reveals when it did. Fix 1 alone is worth more than Fix 2 alone.

## Fix 3 -- pre-verify mechanical claims before spawning auditors

Zero-cost procedural change, observed to work during EDMV4 Phase 3. When the dispatching skill
resumed the capped auditors, it supplied verified ground truth for the cheap mechanical claims
(line numbers, counts, file existence). That freed the auditors' remaining turns for judgment work,
and **both of Group B's P0 findings came out of that freed budget**.

Add a step to `skills/audit-srd/SKILL.md` (and its ticket-audit sibling): before spawning, verify
the mechanical claims the auditors would otherwise spend turns re-deriving, and pass them as
established fact.

## Out of scope

- **Proportional fan-out** -- scaling auditor count to document size instead of the fixed "2-3".
  A real improvement that also helps wall-clock, but Fix 2 likely makes it unnecessary, and with
  Fix 1 in place the sentinel will show whether it is still needed. Revisit if truncation recurs
  after Fix 2.
- **Raising producer budgets.** `edm-srd-writer` capped twice during EDMV4 remediation, so 50 is
  arguably low for producers too. Out of scope here: this initiative is about the verifier
  asymmetry, and raising both sides preserves the gap rather than closing it. Record as a
  named follow-on if it recurs.
- **Any change to the code-audit lenses' `maxTurns: 30`.** No evidence of truncation there.

## Affected files

| File | Change |
|---|---|
| `agents/edm-qc-auditor.md` | Emit the sentinel as the shard's final line; `maxTurns` 25 -> 50 |
| `agents/edm-srd-auditor.md` | Emit the sentinel terminating returned findings; `maxTurns` 25 -> 50 |
| `agents/edm-ticket-auditor.md` | Same; `maxTurns` 25 -> 50 |
| `agents/edm-test-coverage-auditor.md` | Sentinel in `test-coverage.md`; `maxTurns` 25 -> 50 |
| `skills/implement/SKILL.md` | Merge step refuses a shard without a valid sentinel |
| `skills/audit-srd/SKILL.md` | Check the sentinel; add the pre-verification step |
| `skills/audit-tickets/SKILL.md` | Check the sentinel |
| `skills/test-coverage/SKILL.md` | Check the sentinel |
| `bin/tests/wave7-smoke.sh` | Assertions: sentinel present in all four agent prompts; all four at `maxTurns: 50`; negative test that a stripped sentinel makes the merge refuse |
| `CLAUDE.md` | Document the sentinel contract; update the testing-layer agent inventory's maxTurns column |
| `CHANGELOG.md` | `[3.2.2]` entry |
| `.claude-plugin/plugin.json` | `3.2.1` -> `3.2.2` |
| `../../.claude-plugin/marketplace.json` | edm version `3.2.1` -> `3.2.2` |

## Acceptance

1. A truncated QC shard **blocks** the merge with a named error rather than being merged silently.
2. A shard whose `audited=` count is below its assigned `range=` is refused the same way.
3. All four verifiers run at `maxTurns: 50`.
4. Negative tests exist for both refusal paths and fail if the check is removed.
5. `bash plugins/edm/bin/tests/run-all.sh` passes.
6. Version is `3.2.2` in both the plugin manifest and the marketplace manifest.
