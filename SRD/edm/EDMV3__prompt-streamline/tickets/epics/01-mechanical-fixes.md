# Epic E1 -- WS1: Mechanical fixes

**Wave**: A (v2.0.0 -> v2.1.0)
**SRD requirements**: EDMV3-01 .. EDMV3-07, EDMV3-113 (8)
**Tickets**: EDMV3-T01 .. EDMV3-T04 (4)

Nothing else in this initiative is credibly testable while `edm-init` breaks every fresh initiative
and thirteen agents cannot write the artifacts they are ordered to produce. This epic goes first.

All commands below are run from the repository root
(`/Users/darryl.porter/projects/marketplace`) unless stated otherwise.

---

## EDMV3-T01: Correct the `edm-init` branch handshake and cover it with regression tests

| Field | Value |
|---|---|
| Epic | E1 -- Mechanical fixes |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-01, EDMV3-02 |
| Depends On | EDMV3-T19 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-init:139` (the `edm-state init` call), `plugins/edm/bin/edm-init:148-168` (the branch block, `git checkout -b` at `:164`, warn-and-continue at `:162` and `:166`), `plugins/edm/bin/edm-state:498` (`cmd_init`), `plugins/edm/bin/edm-state:53` (`list_state_files`), `plugins/edm/bin/tests/wave6-smoke.sh` (new), `plugins/edm/bin/tests/_harness.sh` |

### Description

`bin/edm-init` calls `edm-state init` at line 139. `cmd_init` snapshots `initiative_branch` from
`git rev-parse --abbrev-ref HEAD` at that moment. The branch block that creates and checks out
`edm/{prefix-lc}-{description}` runs afterwards at `bin/edm-init:148-168`. Every fresh initiative
therefore records the branch the user was on *before* the initiative branch existed, and
`edm-state branch-check` hard-BLOCKs at orchestrator Step 1d with remediation advice
(`git checkout main`) that moves the user off their own branch. This is F2a, and it is the reason
nothing else in the initiative can be tested end to end today.

Per D3 the fix is a **post-checkout correction**, not a reorder. The warn-and-continue paths at
`bin/edm-init:162` and `:166` leave the user on the original branch, so a naive reorder would record
the *intended* branch rather than the *occupied* one -- which is the same bug with a different sign.

The requirement pairs with a regression suite because `edm-init` branch behaviour has zero test
coverage today. The suite is the first consumer of the `_harness.sh` helpers from EDMV3-T19, and it
is the file (`wave6-smoke.sh`) that EDMV3-T14 and EDMV3-T16 later extend.

### Acceptance Criteria

- [ ] AC1 (positive): after the branch block at `bin/edm-init:148-168` completes, `edm-init` runs a
      correction that records the branch actually occupied, derived by reading
      `git rev-parse --abbrev-ref HEAD` at that point rather than from the `$BRANCH` variable, and
      the correction is a no-op outside a git worktree.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "branch recorded equals HEAD").
- [ ] AC2 (positive, success path): on the new-branch path (`git checkout -b` at
      `bin/edm-init:164` succeeds), `.edm-state.json` `initiative_branch` equals the newly created
      branch name.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "new branch path").
- [ ] AC3 (positive, existing-branch path): running `edm-init` when the target branch already
      exists records that branch.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "existing branch path").
- [ ] AC4 (negative, warn-and-continue path): when checkout fails and the user stays on the
      original branch, `initiative_branch` equals the **original** branch name, `edm-init` still
      exits 0, and the scaffold summary still prints the `[warn]` line unchanged.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "checkout failure keeps origin
      branch") -- the case stubs `git` on `PATH` so `checkout` returns non-zero.
- [ ] AC5: immediately after `edm-init` returns, `edm-state branch-check <PREFIX>` exits 0 in every
      one of the three cases above.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (three `branch-check exits 0`
      assertions).
- [ ] AC6 (negative, allowlist containment): the correction uses a dedicated code path -- an
      `edm-state record-branch <PREFIX>` behaviour or an equivalent internal call that reads
      `git rev-parse --abbrev-ref HEAD` itself -- and does **not** widen the `cmd_set` allowlist.
      `initiative_branch` is not a `cmd_set`-settable key.
      Verify: `grep -rn 'edm-state set .*initiative_branch' plugins/edm/` returns zero results
      (this is also asserted by EDMV3-T09's caller contract test).
- [ ] AC7: each smoke case creates its scratch repository under a temp directory via
      `with_scratch_repo` (EDMV3-T19) and removes it on exit including on failure and on interrupt,
      so a failing run leaves no residue in the developer tree.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh && git status --porcelain` prints nothing
      new.
- [ ] AC8: `bash -n` passes over `bin/edm-init` and `bin/tests/wave6-smoke.sh`, and no bash 4+
      construct is introduced (EDMV3-105).
      Verify: `bash -n plugins/edm/bin/edm-init && bash -n plugins/edm/bin/tests/wave6-smoke.sh`
      then `grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}' plugins/edm/bin/edm-init`
      returns zero results.
- [ ] AC9: the new suite is discovered by `bin/tests/run-all.sh`'s auto-discovery (this ticket
      originally registered it in a CI test stage, EDMV3-T21; that pipeline was later removed, D63).
      Verify: `bash plugins/edm/bin/tests/run-all.sh` output lists the new suite by name.

### Technical Notes

- The correction must run **after** line 168 (`fi` closing the worktree guard) so it sees the final
  HEAD, and must itself be guarded by `git rev-parse --is-inside-work-tree` because `edm-init`
  supports non-git directories.
- Do not use `git symbolic-ref`: a detached HEAD is a real state here and
  `git rev-parse --abbrev-ref HEAD` returning `HEAD` is the correct recorded value in that case.
  Record it and let `branch-check` report the mismatch rather than inventing a branch name.
- The checkout-failure case is the awkward one. The cleanest simulation is a `git` shim earlier on
  `PATH` that passes every subcommand through to the real `git` except `checkout -b`, which it
  fails. Creating a file named after the branch under `.git/refs/heads/` also works but is brittle
  across git versions.
- `bin/edm-init:60` calls `edm-validate-prefix` and `:139` calls `edm-state`, both **by bare name**.
  `with_scratch_repo` must prepend `plugins/edm/bin` to `PATH` or the suite fails for a reason
  unrelated to what it tests. This is why the ticket depends on EDMV3-T19.
- bash 3.2 only: no `declare -A`, no `mapfile`, no `${var^^}`.

### Out of Scope

- Reordering `edm-init` so the branch is created before `edm-state init` -- rejected by D3 and
  recorded in `architecture.md` Rejected Alternatives.
- Any change to `cmd_branch_check` itself (`bin/edm-state:1264-1286`). Its logic is correct; it is
  fed a wrong value.
- Making `branch-check` a BLOCK on the standalone-skill path. That is EDMV3-45 and lands in
  EDMV3-T36.
- Adding `initiative_branch` to the `cmd_set` allowlist. Explicitly forbidden by AC6.

---

## EDMV3-T02: Grant `Write` to the thirteen-agent F3 class and bound the blast radius

| Field | Value |
|---|---|
| Epic | E1 -- Mechanical fixes |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-03, EDMV3-04, EDMV3-05, EDMV3-66 (wave-A downgrades), EDMV3-93 |
| Depends On | EDMV3-T22 |
| Ships-with | -- |
| Target Components | `plugins/edm/agents/edm-qc-auditor.md:5` (`tools:`), `:10` (`disallowedTools:`), `:71` and `:76` (output paths, `mkdir -p`); `plugins/edm/agents/edm-explorer.md:5`, `:10`, `:61`; `plugins/edm/agents/edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring}.md` (frontmatter and `## Output`); `plugins/edm/agents/edm-audit-synthesizer.md` (frontmatter, no `disallowedTools` line today); `plugins/edm/skills/code-audit/SKILL.md:40` (`mkdir -p "${OUTPUT_DIR}"`), `:44`, `:99`; `plugins/edm/hooks/hooks.json:117` |

### Description

F3 is a class of thirteen agents, not two. `agents/edm-qc-auditor.md:5` grants neither `Write` nor
`Bash` and `:10` sets `disallowedTools: Write, Edit, NotebookEdit`, yet the agent is told to write
`qc/qc-summary.md` (`:71`), to run `mkdir -p` (`:76`), and -- by the `SubagentStop` hook prompt at
`hooks/hooks.json:117` -- to call `edm-state record-partial-verdict`. `agents/edm-explorer.md` has
the identical contradiction at `:5`, `:10` and `:61`; it was reproduced live during this initiative,
where both EDMV3 explorers returned their reports as chat text with "I have no Write tool"
apologies. All eleven `edm-audit-*` lenses carry the same deny list while
`skills/code-audit/SKILL.md:44` and `:99` order each of them to write
`${OUTPUT_DIR}/lens-L{N}.md`.

The synthesizer has the **opposite** defect and is fixed in the same ticket because it is the same
**Size justification (M).** Round-1 ticket audit resized this from S. The ticket touches 14 agent
files, hand-writes 12 `## Output` contracts that differ only in a lens number, runs a recorded
runtime spike (AC2) whose result decides which of two frontmatter shapes is implemented, and closes
its class with a live single-lens spot run against the eval fixture (AC8). Fourteen files plus a
spike plus a behavioural verification is not a one-component, clear-path change; sizing it S
understated the review surface and the spike's schedule risk.

review pass: `agents/edm-audit-synthesizer.md:5` grants `Read, Write, Edit, Glob, Grep, LS,
NotebookRead, WebFetch, TodoWrite, WebSearch` with **no `disallowedTools:` line at all**, so the
"in-place modification of the audited source is impossible" argument that RK-4 and EDMV3-93 rest on
has a hole in the twelfth code-audit agent -- the one running `opus`/`max` over the same source.

Granting `Write` to eleven read-only agents is the largest new attack surface in the design
(`architecture.md` R-E). The blast radius is bounded by three things delivered here: `Edit` and
`NotebookEdit` stay denied for all twelve code-audit agents, each `## Output` section names exactly
the permitted write paths and declares anything else a contract violation, and audits run against a
committed branch so a stray write shows in `git status`.

### Acceptance Criteria

- [ ] AC1 (positive, qc-auditor): `agents/edm-qc-auditor.md` frontmatter `tools:` includes `Write`
      plus the `Bash` grant it needs for `edm-state`, `mkdir` and `jq`, and `disallowedTools:` is
      exactly `Edit, NotebookEdit`.
      Verify: `grep -n '^tools:\|^disallowedTools:' plugins/edm/agents/edm-qc-auditor.md` shows
      `Write` present in `tools:` and absent from `disallowedTools:`.
- [ ] AC2 (scoped-grant decision, recorded not assumed): a five-minute check runs **before** the
      scoped-grant edit -- grant `Bash(edm-state *)` to one agent, run `claude plugin validate`, and
      confirm the agent can call `edm-state` but not an arbitrary command. If scoped grants are
      honoured, `Bash` is granted in the narrowest form the frontmatter supports and a bare
      unrestricted `Bash` token is a failing condition. If they are not, the bare token is used and
      the limitation is recorded in the agent's frontmatter comment. Exactly one branch is
      implemented and the ticket states which.
      Verify: `grep -n 'scoped-grant' SRD/edm/EDMV3__prompt-streamline/decisions.md` returns the
      recorded result with its date, and `claude plugin validate plugins/edm/` exits 0.
- [ ] AC3 (positive, explorer): `agents/edm-explorer.md` `tools:` includes `Write`,
      `disallowedTools:` is exactly `Edit, NotebookEdit`, and the output section names the exact
      permitted path pattern `<initiative-dir>/explorers/{NN}-{slug}.md`.
      Verify: `grep -n '^tools:\|^disallowedTools:\|explorers/{NN}-{slug}.md' plugins/edm/agents/edm-explorer.md`.
- [ ] AC4 (positive, eleven lenses): all eleven `agents/edm-audit-*.md` lens files (excluding the
      synthesizer) grant `Write` and set `disallowedTools:` to exactly `Edit, NotebookEdit`.
      Verify: `for f in plugins/edm/agents/edm-audit-*.md; do case "$f" in *synthesizer*) continue;; esac; grep -q '^tools:.*Write' "$f" || echo "MISSING Write: $f"; grep -q '^disallowedTools: Edit, NotebookEdit$' "$f" || echo "BAD deny: $f"; done`
      prints nothing.
- [ ] AC5 (negative, synthesizer over-grant closed): `agents/edm-audit-synthesizer.md` gains
      `disallowedTools: Edit, NotebookEdit` and an `## Output` contract naming exactly two permitted
      write paths, `code-audit/findings-ledger.jsonl` and `code-audit/pass-N_DATE/REMEDIATION.md`.
      Verify: `grep -n '^disallowedTools:' plugins/edm/agents/edm-audit-synthesizer.md` returns
      `Edit, NotebookEdit`, and `grep -c 'findings-ledger.jsonl\|REMEDIATION.md' plugins/edm/agents/edm-audit-synthesizer.md`
      is non-zero.
- [ ] AC6 (negative, in-place edit impossible): `Edit` and `NotebookEdit` are denied for all twelve
      code-audit agents, so in-place modification of the source under audit cannot happen.
      Verify: `for f in plugins/edm/agents/edm-audit-*.md; do grep -q 'disallowedTools:.*Edit' "$f" || echo "EDIT NOT DENIED: $f"; done`
      prints nothing.
- [ ] AC7 (bounded write paths): each lens `## Output` section names exactly two permitted write
      paths, both under the current pass directory (`${OUTPUT_DIR}/lens-L{N}.md` and
      `${OUTPUT_DIR}/lens-L{N}.jsonl`), and states that writing anywhere else is a contract
      violation. The contract also names `skills/code-audit/SKILL.md:40`'s
      `mkdir -p "${OUTPUT_DIR}"` as load-bearing -- it is why a lens needs `Write` but no
      `Bash(mkdir *)`.
      Verify: `grep -lc 'contract violation' plugins/edm/agents/edm-audit-*.md | wc -l` prints 12
      (eleven lens files plus the synthesizer).
- [ ] AC8 (behavioural, no proxying -- single-lens live spot run): `/edm:code-audit <FIXTURE>
      --lenses L1` run against the eval fixture initiative (EDMV3-T22) produces
      `code-audit/pass-*/lens-L1.md` **on disk, written by the agent itself**, with no proxying step
      in the transcript, and creates no file outside the pass directory. One lens is sufficient and
      is deliberate: the grant class is identical across all eleven files (asserted statically by
      AC4 and by `edm-check-grants` in EDMV3-T03), so an eleven-lens `opus` round would spend the
      cost of a full audit to re-prove one boolean.
      Verify: `ls <init-dir>/code-audit/pass-*/lens-L1.md | wc -l` prints 1, and
      `git status --porcelain | grep -v 'code-audit/pass-' | wc -l` prints 0. The transcript
      excerpt showing the agent's own `Write` call is pasted into the ticket's QC evidence.
- [ ] AC9: `claude plugin validate` passes with no new warnings relative to the recorded v2.0.0
      baseline.
      Verify: `claude plugin validate plugins/edm/` and compare the warning count against the
      baseline recorded in `plugins/edm/CHANGELOG.md`.
- [ ] AC10 (class closed): after this ticket, `bin/edm-check-grants` (EDMV3-T03) reports zero
      unsatisfied agents. Before it, the same script reports exactly 13.
      Verify: `bash plugins/edm/bin/edm-check-grants` exits 0 (both counts are recorded in
      EDMV3-T03's QC evidence).
- [ ] AC12 (prose-change convention, EDMV3-69): the twelve `## Output` contracts this ticket
      hand-writes are prompt text, so the merge request shows before and after for each changed
      block plus one sentence on why the new wording is better. The eleven lens contracts differ
      only in a lens number and are shown once as a canonical before/after plus the eleven-file
      list; the synthesizer's contract is shown individually because its permitted paths differ.
      Verify: the MR description contains the canonical lens before/after with its file list and a
      separate before/after for `agents/edm-audit-synthesizer.md`.
- [ ] AC11 (rejected alternative recorded): the rejected alternative -- keep lenses read-only and
      persist their output from the code-audit skill -- and the accepted residual risk are recorded
      in `decisions.md`, so a future reviewer sees the trade was deliberate.
      Verify: `grep -n 'lens Write grant' SRD/edm/EDMV3__prompt-streamline/decisions.md`.
- [ ] AC13 (D16 wave-A model downgrades, positive and negative): `agents/edm-explorer.md` and
      `agents/edm-test-coverage-auditor.md` move from `opus`/`max` to `sonnet`/`high`;
      `agents/edm-architect.md` moves from `opus`/`max` to `opus`/`high`. NO other agent's
      `model:`/`effort:` value changes in this ticket or anywhere in wave A -- the contested set
      (eleven lenses, `edm-srd-auditor`, `edm-ticket-auditor`, `edm-qc-auditor`,
      `edm-audit-synthesizer`) stays `opus`/`max` until the EDMV3-T48 tiering matrix (EDMV3-66).
      Verify: `grep -n '^model:\|^effort:' plugins/edm/agents/edm-explorer.md plugins/edm/agents/edm-test-coverage-auditor.md plugins/edm/agents/edm-architect.md`
      shows the three new values, and
      `grep -l '^model: opus' plugins/edm/agents/edm-audit-*.md plugins/edm/agents/edm-srd-auditor.md plugins/edm/agents/edm-ticket-auditor.md plugins/edm/agents/edm-qc-auditor.md | wc -l`
      prints 15.

### Technical Notes

- Scoped `Bash(...)` syntax is documented for SKILL.md `allowed-tools`, **not** for agent `tools:`,
  and has zero precedent in this plugin: every `Bash`-holding agent today uses a bare token
  (`agents/edm-implementer.md`, `agents/edm-test-coverage-auditor.md`, and eight more). AC2 is why
  this ticket does the check first rather than assuming.
- `hooks/hooks.json:117` is a `type: prompt` hook. Its step 6 instructs `edm-qc-auditor` to call
  `edm-state record-partial-verdict`, which is why the `Bash` grant is not optional and why
  `edm-check-grants` must read hook prompts as an instruction source (EDMV3-T03).
- Do not touch the QC verdict semantics at `agents/edm-qc-auditor.md:26-48`. They are on the
  preserve-untouched list (EDMV3-111) and only the note token changes, in EDMV3-T31.
- Eleven near-identical edits: script the frontmatter change and hand-write the `## Output`
  contracts, because the two permitted paths differ only in the lens number.
- **Depends on EDMV3-T22.** AC8's spot run needs the eval fixture initiative and the scratch SRD
  root the driver provisions. Both tickets are wave A, so wave order alone does not guarantee the
  fixture exists first -- the edge is declared rather than assumed. AC8 does **not** need the
  headless driver itself; it needs `evals/fixtures/tiny-svc/` and `evals/initiative.txt` on disk.

### Out of Scope

- The JSONL emission itself (EDMV3-30) -- that is EDMV3-T24 in wave B. This ticket only makes it
  physically possible.
- `AskUserQuestion` grants to skills (EDMV3-113) -- that is EDMV3-T03.
- The `edm-check-grants` script itself -- EDMV3-T03.
- Any change to the eleven lenses' hunting briefs or False Alarm Filters (EDMV3-32 / EDMV3-T25).

---

## EDMV3-T03: Build `bin/edm-check-grants` over four instruction sources and grant `AskUserQuestion`

| Field | Value |
|---|---|
| Epic | E1 -- Mechanical fixes |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-07, EDMV3-113 |
| Depends On | EDMV3-T02, EDMV3-T09 |
| Ships-with | EDMV3-T15 |
| Target Components | `plugins/edm/bin/edm-check-grants` (new), `plugins/edm/bin/edm-lint-artifacts:59` (`report_violation`), `:69` (`build_ignore_set`), `:112` (`is_ignored_line`), `plugins/edm/agents/*.md` (30 files), `plugins/edm/skills/*/SKILL.md` (13 files), `plugins/edm/hooks/hooks.json`, `plugins/edm/skills/{code-audit,plan,audit-srd,audit-tickets}/SKILL.md:8` (`allowed-tools`) |

### Description

The tool-grant contradiction was found once for `edm-test-coverage-auditor` and encoded as a
permanent manual ritual at `skills/implement/SKILL.md:162-172` instead of a class-level test. Per
`architecture.md` R-F, the check as originally specified -- "grep every `agents/*.md`" -- would pass
green while eleven lenses remain unable to write, because the lenses receive their write instruction
from `skills/code-audit/SKILL.md:44,99` and `edm-qc-auditor` receives one from `hooks/hooks.json:117`.
The check must span **four** instruction sources: agent bodies, skill launch templates, hook prompt
text, and skill `allowed-tools`.

The fourth source exists because the same class defect sits one level up. `AskUserQuestion` appears
in exactly one `allowed-tools` line in the whole plugin -- `skills/orchestrator/SKILL.md:8` -- while
EDMV3-20, EDMV3-48, EDMV3-49 and EDMV3-78 all require gate presentation from
`skills/code-audit`, `skills/plan`, `skills/audit-srd` and `skills/audit-tickets`. Without the
grant, the gate protocol is physically un-runnable in four skills. The fifth
(`skills/verify-runtime/SKILL.md`) does not exist until wave B and is handled by EDMV3-T33.

### Acceptance Criteria

- [ ] AC1 (four sources): `plugins/edm/bin/edm-check-grants` is a new executable that collects
      write and shell instructions from four sources -- agent bodies under `agents/*.md`, skill
      launch templates under `skills/*/SKILL.md` naming a target agent and a write path, hook
      prompt text in `hooks/hooks.json`, and each skill's own body versus its `allowed-tools`.
      Verify: `bash plugins/edm/bin/edm-check-grants --list-sources` prints exactly four source
      labels.
- [ ] AC2 (positive direction, instruction implies grant): for every `(agent, write-instruction)`
      pair found, the script asserts that agent's frontmatter grants `Write` in `tools:` and does
      not list `Write` in `disallowedTools:`. The same cross-reference is applied to `Bash` where
      an instruction names a shell command (`edm-state`, `mkdir`, `jq`).
      Verify: `bash plugins/edm/bin/edm-check-grants` exits 0 after EDMV3-T02 lands.
- [ ] AC3 (negative direction, grant without instruction warns): any agent granting `Write`, `Edit`
      or `Bash` with no corresponding instruction in the four sources is reported as a **warning**,
      so over-granting becomes visible. A one-directional check would never have surfaced the
      synthesizer's unexplained `Edit` grant.
      Verify: `bash plugins/edm/bin/edm-check-grants 2>&1 | grep -c 'warning: grant-without-instruction'`
      returns the recorded expected count, and reverting `agents/edm-audit-synthesizer.md` to its
      pre-T02 frontmatter in a scratch copy makes the warning appear.
- [ ] AC4 (must-fail, pre-state): running the script against the tree **before** EDMV3-T02 lands
      reports exactly 13 unsatisfied agents. Both the before and after counts are recorded in the
      ticket's QC evidence.
      Verify: `git stash && bash plugins/edm/bin/edm-check-grants | grep -c '^agent:' && git stash pop`
      prints 13.
- [ ] AC5 (skill grants, positive): `AskUserQuestion` is present in `allowed-tools` in
      `skills/code-audit/SKILL.md`, `skills/plan/SKILL.md`, `skills/audit-srd/SKILL.md` and
      `skills/audit-tickets/SKILL.md`. `skills/orchestrator/SKILL.md:8` already has it and is
      unchanged.
      Verify: `for s in code-audit plan audit-srd audit-tickets orchestrator; do grep -q 'AskUserQuestion' "plugins/edm/skills/$s/SKILL.md" || echo "MISSING: $s"; done`
      prints nothing.
- [ ] AC6 (skill grants, must-fail): the extended checker fails when a skill's body uses a tool its
      `allowed-tools` does not list. Running it before this ticket reports **exactly four** skills
      missing `AskUserQuestion` -- `code-audit`, `plan`, `audit-srd`, `audit-tickets`. Four, not
      five: `AskUserQuestion` appears in exactly one `allowed-tools` line in the tree today
      (`skills/orchestrator/SKILL.md:8`, verified 2026-07-25) and the fifth holder,
      `skills/verify-runtime/SKILL.md`, does not exist until EDMV3-T33 creates it in wave B with the
      grant already present. After EDMV3-T38, one skill (`orchestrator`) additionally requires
      `Skill`. Both counts are recorded in the ticket's QC evidence.
      Verify: create a scratch copy with `AskUserQuestion` removed from
      `skills/plan/SKILL.md:8` and confirm `bash plugins/edm/bin/edm-check-grants` exits 1 naming
      `skills/plan/SKILL.md`.
- [ ] AC7 (output and exit contract): output format is
      `agent: <name>: <class>: <instruction source path:line>`; exit 0 clean, 1 on any unsatisfied
      pair, 2 on a usage or environment error (EDMV3-100).
      Verify: `bash plugins/edm/bin/edm-check-grants --bogus-flag; echo "exit=$?"` prints `exit=2`.
- [ ] AC8 (no re-derived file walk): the script sources or mirrors `report_violation`
      (`bin/edm-lint-artifacts:59`), `build_ignore_set` (`:69`) and `is_ignored_line` (`:112`)
      rather than re-implementing the file walk and ignore handling.
      Verify: `grep -n 'report_violation\|build_ignore_set\|is_ignored_line' plugins/edm/bin/edm-check-grants`
      returns hits.
- [ ] AC9 (count drift guard): a smoke assertion ties the documented agent count to reality -- the
      number of agents named in `plugins/edm/CLAUDE.md` equals `ls plugins/edm/agents/*.md | wc -l`
      (30) -- so the 26-versus-30 drift cannot recur.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "documented agent count matches
      disk").
- [ ] AC10 (bash 3.2): the script uses no associative arrays and no `mapfile`, passes
      `bash -n`, and runs in the smoke aggregator (this ticket originally also registered it in a CI
      lint stage, EDMV3-T21; that pipeline was later removed, D63).
      Verify: `bash -n plugins/edm/bin/edm-check-grants` and
      `grep -n 'edm-check-grants' plugins/edm/bin/tests/run-all.sh`.
- [ ] AC11: `claude plugin validate` passes with no new warnings after the four frontmatter edits.
      Verify: `claude plugin validate plugins/edm/`.

### Technical Notes

- The instruction-detection heuristic is the hard part. Keep it conservative and explicit: a write
  instruction is a line containing a path-shaped token (`*.md`, `*.jsonl`, a directory with a
  trailing slash) within N lines of one of a committed verb list (`write`, `writes`, `emit`,
  `produce`). False negatives here are the dangerous direction, so bias the verb list wide and
  accept warnings.
- `hooks/hooks.json` prompt text is JSON-escaped. Parse it with `jq -r` rather than grepping the raw
  file, or step 6 of the `SubagentStop` prompt will be missed.
- The instruction for a lens lives in `skills/code-audit/SKILL.md:44` and `:99`, not in the agent
  body. The source-2 matcher must associate the launch template with the target agent name, which
  the template states explicitly.
- Exit code 2 is reserved for usage or environment errors across all new `bin/edm-check-*` scripts
  (EDMV3-100). `edm-state` subcommands keep their own convention -- do not unify them.
- This ticket ships in the same MR as EDMV3-T15, which is the first skill to use the new
  `AskUserQuestion` grant. `Ships-with` is a same-MR relationship and **not** a build-order edge, so
  EDMV3-T15 does not carry EDMV3-T03 in its `Depends On` -- the two fields would otherwise say
  contradictory things about the same pair.
- **Depends on EDMV3-T09.** AC9's count-drift guard is a case in `bin/tests/wave7-smoke.sh`, and
  that suite is created by EDMV3-T09. Without the edge, AC9 names a file that may not exist yet.

### Out of Scope

- Deleting the manual ritual at `skills/implement/SKILL.md:162-172`. That is EDMV3-81 and lands as
  EDMV3-T58 in wave C, after this test exists to replace it. srd.md v1.2.0 (CR1) rewords EDMV3-07
  AC11 to match: the deletion is EDMV3-81's obligation, not a same-MR requirement of this ticket,
  and the ordering edge is recorded in SRD Section 11.2.
- The `verify-runtime` skill's frontmatter contract (EDMV3-113 wave-B clause) -- EDMV3-T33.
- Adding `Skill` to the orchestrator's `allowed-tools` -- EDMV3-T38.
- Fixing any grant this check finds outside the 13-agent class. If the checker surfaces a
  fourteenth, it is recorded as a finding and given its own ticket rather than fixed silently here.

---

## EDMV3-T04: Fix the README install path and state the platform constraint

| Field | Value |
|---|---|
| Epic | E1 -- Mechanical fixes |
| Wave | A |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV3-06, EDMV3-106 |
| Depends On | EDMV3-T09 |
| Ships-with | -- |
| Target Components | `plugins/edm/README.md:11`, `:14`, plus a new Requirements section; `plugins/edm/CLAUDE.md` ("Testing changes" section) |

### Description

`README.md:11` and `:14` install `./plugins/edm-ai-development`, a directory renamed to
`plugins/edm`. Step one of the documented journey 404s. The stale-path class is two paths, not one:
`plugins/edm/CLAUDE.md` "Testing changes" separately tells contributors to run
`claude plugin validate edm-plugin/` and `claude --plugin-dir ./edm-plugin`, and `edm-plugin/` does
not exist either.

D11 additionally requires the macOS/Linux-only constraint to be **stated** rather than implied, so a
prospective user is not left to discover it by failure. That statement is the documentation half of
EDMV3-106 (macOS and Linux only); EDMV3-T61 owns the enforcement half in `bin/`.

EDMV3-87 (Windows and WSL are not supported) is a **Won't Have** and is a recorded scope boundary,
not a delivery of this ticket, so it does not appear in `SRD Refs`. AC7 is the negative enforcement
that keeps the boundary true, and the boundary's disposition is recorded in the README coverage map.

### Acceptance Criteria

- [ ] AC1 (positive): `README.md:11` reads `claude plugin install ./plugins/edm` and `:14` reads
      `claude --plugin-dir ./plugins/edm`.
      Verify: `sed -n '11p;14p' plugins/edm/README.md`.
- [ ] AC2 (positive): `plugins/edm/CLAUDE.md` "Testing changes" steps 1 and 2 read
      `claude plugin validate plugins/edm/` and `claude --plugin-dir ./plugins/edm`.
      Verify: `grep -n 'claude plugin validate\|--plugin-dir' plugins/edm/CLAUDE.md`.
- [ ] AC3 (negative, class closed): the stale directory names are gone from the whole plugin tree
      except changelog history.
      Verify: `grep -rn 'edm-ai-development\|edm-plugin/' plugins/edm/ | grep -v CHANGELOG.md`
      returns zero results.
- [ ] AC4: `README.md` contains a Requirements or Platform section stating macOS and Linux only,
      bash 3.2 or newer, `jq` required, `git` required, and naming Windows and WSL as unsupported.
      Verify: `grep -n 'macOS' plugins/edm/README.md` and
      `grep -cn 'WSL' plugins/edm/README.md` is non-zero.
- [ ] AC5 (single statement, not three): the same constraint appears once in
      `plugins/edm/CLAUDE.md` and is not restated a third time anywhere in the plugin.
      Verify: `grep -rln 'Windows and WSL are unsupported' plugins/edm/` returns exactly two files
      (`README.md` and `CLAUDE.md`).
- [ ] AC6 (regression guard, positive and negative): a smoke assertion checks that `README.md`
      contains the string `./plugins/edm` **and** does not contain `edm-ai-development`.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "README install path present" and
      "README stale path absent").
- [ ] AC7: no Windows or WSL compatibility work is performed and no requirement in the tree assumes
      a Windows path separator or PowerShell (EDMV3-87).
      Verify: `grep -rn 'powershell\|C:\\\\' plugins/edm/bin plugins/edm/skills plugins/edm/agents`
      returns zero results.
- [ ] AC8: the edited files are ASCII-only and pass the content lint.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0 (or, before EDMV3-T20 lands,
      `LC_ALL=C grep -n '[^\x00-\x7F]' plugins/edm/README.md plugins/edm/CLAUDE.md` returns
      nothing).

### Technical Notes

- The repository-root `CLAUDE.md` also has an out-of-date Current Plugins list that omits `edm`.
  That edit belongs to EDMV3-T21 (CI ticket, EDMV3-23 AC2), not here -- do not do it twice.
- Keep the Requirements section short. It is a user-facing README, and EDMV3-60's anti-padding
  clause applies to this pack's own output as much as to the plugin's.
- **Depends on EDMV3-T09.** AC6's regression guard is a case in `bin/tests/wave7-smoke.sh`, created
  by EDMV3-T09. The edge exists so a wave-A implementer picking this XS ticket up first does not
  find themselves creating a smoke suite that another ticket owns.

### Out of Scope

- The permission `ask` rules block in `README.md` (EDMV3-08) -- that is EDMV3-T06.
- The `verify-runtime` entry in the README command table (EDMV3-41) -- EDMV3-T33.
- The README timing table regeneration (EDMV3-74) -- EDMV3-T53.
- Any actual portability work in `bin/` (EDMV3-106) -- EDMV3-T61.
