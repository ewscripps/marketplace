# Code Audit Remediation Plan: EDMV3 (EDMV3__prompt-streamline) -- Round 11

## Context

- **Audit date**: 2026-08-22
- **Round**: 11 (pass-11_2026-08-22)
- **Round type**: **full** -- all 11 lenses ran (L1-L11), per `lenses-run.txt`. A full round *can*
  satisfy the convergence gate; **this one does not** (see Convergence Gate Status below).
- **Audited scope**: the `edm` plugin itself -- `plugins/edm/**` (bin, bin/tests, evals, skills,
  agents, hooks, monitors, docs), the repository-root `.gitlab-ci.yml`, the repository-root
  `CLAUDE.md` and `.gitignore`, and this initiative's own SRD artifacts
  (`SRD/edm/EDMV3__prompt-streamline/**`). Self-referential audit/hardening pass.
- **Tree audited**: working tree at pass-11 start, post-`0b2f304`
  ("Add comprehensive round 10 audit artifacts and logic corrections across L1 findings").
- **SRD**: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.4.0)
- **Ticket pack**: `SRD/edm/EDMV3__prompt-streamline/tickets/` (11 epic files + `README.md`)
- **Decisions**: `SRD/edm/EDMV3__prompt-streamline/decisions.md` (D1-D62)
- **Ledger (authoritative)**: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`
- **Deployment target**: local plugin distribution (marketplace repo); CI = GitLab pipeline scoped
  to `plugins/edm/**`

### Round-11 ledger state

| Severity | Open | Notes |
|---|---:|---|
| **P0** | **0** | none this round, and none since round 2 |
| **P1** | **2** | CA-515 (lens-conflict adjudication), CA-536 (escalated P2 -> P1) |
| **P2** | **40** | 15 carried, 1 upgraded from NOTED (CA-171), 24 new |
| **NOTED** | 69 | includes CA-130 (11th consecutive round; process, non-blocking) |
| fixed | 451 | **45 closed this round** (43 open->fixed, CA-521 open->noted, CA-535 noted->fixed) |
| **Total ledger entries** | **562** | CA-001 .. CA-562; 26 new IDs minted this round (CA-537..CA-562) |

### Convergence Gate Status: **NOT SATISFIED**

This was a full round, so it is *eligible* to satisfy the gate, but the blocking set is non-empty:
**2 open P1 findings (CA-515, CA-536)**. Both are single-commit fixes with concrete, file-level
instructions below. P2s do not block. `CA-130` is NOTED and must not be treated as blocking.

Round 11 was nonetheless the strongest remediation round of the initiative: **45 findings closed**,
including every open L8 finding (7/7), 6 of 7 open L10 findings, 7 of 8 open L3 findings, and all
three P1s carried in from round 10 that were genuinely fixed (CA-509, CA-510, CA-513, CA-514,
plus CA-106 closed via its sanctioned scope route).

---

## Findings Summary

### Blocking (P0 / P1)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| G1 | **P1** | **L10+L11** (L3 dissent) | `plugins/edm/agents/edm-qc-auditor.md:81` (+4 more) | **CA-515** -- threshold-shard filename fix swept 1 of 6 copies; the writing agent still specifies the colliding name, and `wave7-smoke.sh:9388` **pins the bug** |
| G2 | **P1** | L9 | `plugins/edm/bin/edm-state:42`, `:53` | **CA-536** -- T28 AC13 as amended is unsatisfiable: `--help` enumerates no `audit-converged` refusal reason; earliest `spec_swept` token is 1,600 lines past the help block |

### New P2 findings this round (CA-537 .. CA-561)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| G3 | P2 | **L3+L5** | `bin/tests/wave7-smoke.sh:9636-9682` | **CA-541** -- CA-481(c)'s new trap sweep is blind to unquoted handlers, RETURN-only traps, and no-`exit` bodies; two live sites are invisible |
| G4 | P2 | **L5+L7** | `bin/edm-state:5341` | **CA-544** -- last RETURN-only cleanup trap in the plugin; the sibling was hardened this round, this one was never swept, and CA-541 is why the sweep missed it |
| G5 | P2 | L2 | `.gitlab-ci.yml:859-863` | **CA-537** -- residual of CA-490: the CA-452 partial-run exit-4 block is now structurally unreachable; partial signal silently became exit 2 |
| G6 | P2 | L9 | `srd.md:1749-1774`, `:26` | **CA-554** -- residue of CA-106: route-(b) boundary recorded everywhere except `srd.md`; EDMV3-28 still an unqualified undelivered Must Have |
| G7 | P2 | L9 | `srd.md:12`, `:16`, `:1769-1771` | **CA-555** -- CR8's and D61's own document sweeps incomplete (stale Last Updated, "D1-D16", "five dimensions") |
| G8 | P2 | L9 | `tickets/epics/04-structured-findings.md:608-615`, `:627-629` | **CA-553** -- AC14's landing commit shipped its own sweep debt: stale Verify range + two contradicting AC-band notes |
| G9 | P2 | L10 | `bin/edm-state:5350-5351`, `:5361-5362`, `:5383-5384` | **CA-556** -- residual of CA-513: awk skip-set prelude copied 3x; only 1 of 3 arms has a fence regression case |
| G10 | P2 | L7 | `skills/orchestrator/SKILL.md:7` | **CA-549** -- residual of CA-535: the new quoting-rationale comment states a YAML rule that is wrong and that two siblings contradict |
| G11 | P2 | L3 | `evals/run-eval.sh:452` | **CA-540** -- residual of CA-511: hardcoded 3-phase multiplier, and the pin asserts the literal source string |
| G12 | P2 | L8 | `evals/run-eval.sh:460` | **CA-550** -- `EDM_EVAL_MAX_BUDGET_USD` is the only unvalidated `EDM_EVAL_*` knob and it bounds money |
| G13 | P2 | L8 | `evals/run-eval.sh:311`, `:316-318`, `:260-263` | **CA-551** -- single-PID kill leaves credential-bearing grandchildren alive past the containment boundary |
| G14 | P2 | L8 | `.gitlab-ci.yml:864-868` | **CA-552** -- unredacted `runs/` artifact publication from the one credential-bearing job (re-raise of a lost round-8 item) |
| G15 | P2 | L11 | `qc/qc-shard-01.md`, `qc-shard-02.md` | **CA-558** -- two real committed QC shards match neither merge glob while still satisfying the phase gate |
| G16 | P2 | L11 | `bin/edm-check-grants:35-37` | **CA-559** -- grant-without-instruction direction never extended to source 4 (skills); two live dead grants |
| G17 | P2 | L11 | `skills/verify-runtime/SKILL.md:80` | **CA-560** -- writes into `post-deploy/` with no `mkdir -p`, though it holds `Bash(mkdir *)` and both siblings instruct it |
| G18 | P2 | L11 | `evals/fixtures/tiny-svc/src/api/routes.js:10` | **CA-561** -- unreachable `/health` route with no annotation, unlike the fixture's other deliberate dead wiring |
| G19 | P2 | L3 | `bin/edm-init:125-127`, `:130-159`, `:165` | **CA-542** -- no unwind for a partial scaffold, and the retry guard's recovery hint cannot work |
| G20 | P2 | L4 | `bin/tests/wave6-smoke.sh:817` | **CA-543** -- the CA-426 stream-separation pin discards stderr, the stream it exists to test |
| G21 | P2 | L5 | `bin/tests/wave6-smoke.sh:4929-4930` | **CA-545** -- residue of CA-495(b) in the sibling suite: last two scratch files outside the trap-covered root |
| G22 | P2 | L5 | `bin/tests/timing.sh:243` | **CA-546** -- `--generate-fixture`'s self-minted 50-initiative tree is never removed or pruned |
| G23 | P2 | L6 | `plugins/edm/CLAUDE.md:1057` | **CA-547** -- the 100KB eval budget has three docs and two mutually exclusive verdicts, plus an unpinned `~134KB` figure |
| G24 | P2 | L6 | `evals/fixtures/tiny-svc/README.md:38-39` | **CA-548** -- one bullet both distinguishes and collapses the fixture-tree vs whole-tree budget scopes |
| G25 | P2 | L10 | `evals/score-artifacts.sh:163-181` | **CA-557** -- `--describe` re-types all six `DIM_NAMES` as prose literals (CA-503/CA-533 class) |
| G26 | P2 | L2 | `bin/tests/run-all.sh:145-148` | **CA-538** -- byte-identical `printf` on both arms; the condition decides nothing (CA-054 class) |
| G27 | P2 | L2 | `bin/edm-mermaid-rules.awk:96` | **CA-539** -- provably inert bare-keyword guard (sixth member of a class filed and resolved six times) |

### Carried-forward P2 findings (still open, re-verified this round)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| G28 | P2 | **L1+L4** | `wave6-smoke.sh` x6, `wave7-smoke.sh` x5 | **CA-401** -- bare `grep -c` capture aborts the suite on a zero count; partially remediated, 11 sites remain, incl. the G25/CA-342 pins themselves |
| G29 | P2 | **L1+L4** | `wave7-smoke.sh:370` | **CA-491** -- CA-441's Task-grant rule still has no must-fail case; its trigger is false tree-wide |
| G30 | P2 | **L4+L10** | `bin/tests/_harness.sh:248` | **CA-459** -- no `assert_count_with_control`; 66 hand-rolled sites. **Documented debt D60** -- disposition of record, confirmation only |
| G31 | P2 | **L7+L11** | `wave7-smoke.sh:6733`, `:6758` | **CA-496** -- CLI-family durability loop omits the 10th helper. **Fourth consecutive round open** |
| G32 | P2 | L1 (+L8 on the code half) | `.gitlab-ci.yml:322-333` fixed; pin absent | **CA-518** -- code half landed, prescribed pin did not; deleting the guard turns nothing red |
| G33 | P2 | L1 | `wave6-smoke.sh` (absent cases) | **CA-453** -- the four prescribed gates-approved assertions still do not exist (unchanged since round 8) |
| G34 | P2 | L4 | `wave7-smoke.sh:2309` | **CA-402** -- `MERMAID_QUOTED` has zero readers and guarantees a self-hit |
| G35 | P2 | L4 | `wave7-smoke.sh:1105-1110` | **CA-403** -- six positive controls carry no provenance comment |
| G36 | P2 | L4 | `wave7-smoke.sh:751`, `:779`, `:792`, `:822` | **CA-404** -- four scorer dimension extractions discard rc and stderr |
| G37 | P2 | L4 | `wave7-smoke.sh:2862` | **CA-405** -- T44 AC8 presence-only meta-assertion passes with 39 of 40 assertions deleted |
| G38 | P2 | L4 | `wave7-smoke.sh:7726` (+8) | **CA-455** -- nine SKIP paths increment neither counter; lock cases silently never run on macOS |
| G39 | P2 | L4 | `wave7-smoke.sh:1978-1995` | **CA-456** -- four assertions against a fixture the test wrote three lines earlier |
| G40 | P2 | L4 | `wave7-smoke.sh:1096`, `:1108` | **CA-457** -- six-arm regex proven by a one-arm control |
| G41 | P2 | L4 | `wave6-smoke.sh:810-821` | **CA-492** -- zero-round convergence positively certified with no boundary case (see also CA-543) |
| G42 | P2 | L5 | `bin/tests/harness-smoke.sh:45`, `:63`, `:115`, `:139`, `:191` | **CA-171 -- UPGRADED FROM NOTED TO P2** after three rounds held: five untrapped temp files, one across a deliberate `sleep 5` |

---

## Detailed Findings

### G1 (P1, lenses L10 + L11; L3 dissenting): CA-515 -- threshold-shard filename fix reached the describing surface, not the producing one

> **THIS IS A LENS-CONFLICT ADJUDICATION.** It is recorded here explicitly, per the synthesis
> contract, because three lenses reported on CA-515 this round and they did not agree.

**Who said what**

| Lens | Verdict | What it actually read |
|---|---|---|
| **L3** | "**FIXED, clean**" | `skills/implement/SKILL.md:28-152` and `wave7-smoke.sh:9620-9703`. Its own declared scope caveat (N13) does **not** list `agents/edm-qc-auditor.md`, `hooks/hooks.json`, `plugins/edm/CLAUDE.md`'s shard rows, or `wave7-smoke.sh:9387-9388`. |
| **L10** (Finding 1) | **STILL OPEN, P1** | All six copies of the filename spec plus both smoke assertions, read directly at HEAD. |
| **L11** (Finding 1) | **STILL OPEN, P1** | The QC-shard producer/consumer chain end to end, including `agents/edm-qc-auditor.md:81` and `wave7-smoke.sh:9387-9388`. |

**Adjudication: OPEN, P1.** Two independent lenses with concrete `file:line` evidence on the
*authoritative* surface outweigh one lens that checked a *different* surface. Critically, the two
verdicts are **not actually contradictory** -- they are about different files. L3 verified the
**describing** surface (the skill's pseudo-code) and correctly found it fixed; it never read the
**producing** surface. L3's verdict is scope-limited by its own honestly-declared coverage note,
which is exactly what that note is for. No lens contradicts L10/L11's evidence.

**Problem**. The CA-515 remediation reached **1 of 6** copies of the threshold-shard filename spec.

*Fixed (canonical)*: `plugins/edm/skills/implement/SKILL.md:107` and `:111` now write
`qc/qc-shard-pass-w{wave_num:02d}-01.md` and `-{i+1:02d}.md`, with the rationale at `:112-119`.

*Still specifying the pre-fix ordinal-only `qc-shard-pass-{NN}.md`*:

1. `plugins/edm/skills/implement/SKILL.md:84-85` -- **the same file**, the normative "QC output
   paths" bullet, 22 lines above its own fixed pseudo-code. A reader gets two different answers
   22 lines apart.
2. `plugins/edm/agents/edm-qc-auditor.md:81` -- **the writing agent's own Output Path contract**,
   whose worked example is literally the colliding `qc-shard-pass-01.md`.
3. `plugins/edm/hooks/hooks.json:117`
4. `plugins/edm/CLAUDE.md:107`
5. `plugins/edm/CLAUDE.md:696`

Per `plugins/edm/CLAUDE.md`'s own intent-to-file index, an agent's own file is authoritative for how
that agent reports. Site 2 therefore **governs the writer**, so the cross-wave clobber CA-515 was
filed to close is still live at the producer: wave 2's sub-threshold QC pass rewrites wave 1's
filename and silently discards wave 1's PASS/FAIL verdicts, which `skills/implement/SKILL.md:90-91`
confirms live nowhere else (only PARTIAL survives, via the locked `record-partial-verdict`).

**Aggravating -- the suite pins both sides of the contradiction.** `wave7-smoke.sh:9387-9388`
asserts the **stale** literal `qc/qc-shard-pass-{NN}.md` **is present** in
`agents/edm-qc-auditor.md`, while `:9396-9399` asserts the **new** wave-component form **is
present** in `skills/implement/SKILL.md`. Both are green. `:9388` does not merely fail to catch the
bug -- **it pins the bug**, and it pins the exact shape the same file's CA-515 positive control at
`:9400-9404` declares must not ship. That control only `sed`-transforms the skill file's own string
and re-checks the same file, so it is structurally incapable of detecting an unswept sibling.
**Fixing the agent file fails the suite today.**

**Not broken** (checked, so the fix stays scoped): the merge step is unaffected -- the
`qc-shard-pass-*.md` glob at `skills/implement/SKILL.md:39`, `:93-94`, `:122`,
`agents/edm-qc-auditor.md:85`, `hooks/hooks.json:117` and `bin/edm-state:2642` matches the
wave-prefixed name unchanged. CA-473 namespace disjointness also holds under either shape.

**Fix** (ordered; step 2 is mandatory or the suite blocks step 1):

1. Sweep all five stale copies to the wave-keyed form. **`agents/edm-qc-auditor.md:81` first** --
   replace its `qc-shard-pass-01.md` worked example with `qc-shard-pass-w01-01.md` and add the wave
   component to the path template.
2. **Change `wave7-smoke.sh:9388`** from asserting `qc/qc-shard-pass-{NN}.md` to asserting the
   wave-component form in `agents/edm-qc-auditor.md`. As written it pins the defect.
3. Add a cross-file token-equality pin in the `ca473_tokens` shape already used at
   `wave7-smoke.sh:9340-9375`: extract the `qc-shard-pass-*` filename token from each of the six
   surfaces and assert all six are equal, so the next single-site edit fails a test instead of
   shipping. Step 2 alone leaves the other four surfaces unpinned.
4. Sweep `wave6-smoke.sh:2091` in the same commit -- CA-534's fixture (fixed this round) writes the
   ordinal-only `qc-shard-pass-01.md`, exactly as CA-534's own sequencing note anticipated.

**Verification**: `bash plugins/edm/bin/tests/wave7-smoke.sh` and `wave6-smoke.sh` both green;
`grep -rn 'qc-shard-pass-{NN}' plugins/edm/` returns nothing; the new six-way token-equality
assertion turns red when any single surface is perturbed.

**Files affected**: `plugins/edm/agents/edm-qc-auditor.md`,
`plugins/edm/skills/implement/SKILL.md`, `plugins/edm/hooks/hooks.json`,
`plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`,
`plugins/edm/bin/tests/wave6-smoke.sh`.

**Also a `spec_swept` failure (CA-416 class)**: the remediating change altered a behaviour-governing
filename and left five documented copies naming the old one, so `spec_swept: yes` on CA-515 would be
incorrect.

---

### G2 (P1, lens L9): CA-536 -- T28 AC13 as amended is unsatisfiable against shipped code

**Escalated P2 -> P1 this round.**

**Problem**. The ticket half of CA-536 landed exactly as prescribed: T28 AC13 was amended at
`tickets/epics/04-structured-findings.md:577-586` to require that the `--help` block "enumerate
every refusal reason `audit_converged` can return, including the `spec_swept` sweep-debt refusal
added by AC14", with `Verify: edm-state --help | grep -n 'spec_swept\|sweep-debt'`.

The code obligation the amendment creates did **not** land. The `EDM-HELP` sentinel block that
`print_help` emits runs from `bin/edm-state:2` to the `# EDM-HELP-END` marker at `:53`. Its
`audit-converged` line (`:42`) reads only "query code-audit convergence over findings-ledger.jsonl
(read-only)" -- it enumerates **no** refusal reason. The earliest occurrence of `spec_swept` or
`sweep-debt` anywhere in the file is `:1665`, i.e. **1,600 lines past the end of the help block**, so
the amended Verify command returns nothing and **AC13 cannot be closed**.

Secondary divergence inside the same AC: the requirement text says the **`CLAUDE.md` `bin/` table**
enumerates the refusal reasons, but that table's `edm-state` row lists only 39 subcommand *names*;
the refusal reasons live in the state/ledger field table's `spec_swept` row instead. The amended
doc-half Verify (`grep -n 'audit-converged' plugins/edm/CLAUDE.md`) **passes without testing the
clause it is attached to**.

**Why P1**: an amended acceptance criterion is now unsatisfiable against shipped code, and the
operator-facing surface for `audit-converged` documents fewer refusal reasons than the code has.
That is a partial implementation of a spec'd obligation, not a cosmetic gap.

**Identity note (adjudication, recorded for transparency)**: the round-11 brief asked for this to be
treated as a *genuinely new* P1. It is filed under the **existing CA-536** rather than a new ID
because L9's own carry-in table reconciles its new finding to this ID
("CA-536 -- **STILL OPEN** -- see L9-R11-01"), and minting a second ID for a thread the owning lens
explicitly reconciled would double-count one issue against the dedup rule. The **substance** of the
instruction is honoured in full: it is a P1 in the blocking set with a concrete fix. Flagged here so
the orchestrator can override the identity call if it prefers a fresh ID.

**Fix** (small):

1. Add the refusal reasons to the `audit-converged` line inside the `EDM-HELP` block at
   `bin/edm-state:42`, or add a `refusal reasons:` sub-line, naming the sweep-debt arm explicitly
   alongside the existing 0/1/3 exit contract documented in-code at `:4615-4620`.
2. Either re-point AC13's doc clause at `plugins/edm/CLAUDE.md`'s state/ledger field table, or move
   the enumeration into the `bin/` table so the AC text and the file agree.
3. Change AC13's Verify to grep for the **refusal reasons**, not the subcommand name.

**Verification**: `plugins/edm/bin/edm-state --help | grep -n 'spec_swept\|sweep-debt'` returns at
least one line; `bash plugins/edm/bin/tests/wave6-smoke.sh` green.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/CLAUDE.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/04-structured-findings.md`.

---

### G3 (P2, lenses L3 + L5 -- multi-lens): CA-541 -- CA-481(c)'s new trap sweep is blind to shapes it exists to catch

Two lenses filed this independently against the same awk body with the same root cause; merged.

**Problem**. The cross-file trap sweep that finally landed after failing to land across three rounds
(`wave7-smoke.sh:9624-9699`) has four coverage holes:

1. **Parser bug (both lenses)**. `:9643-9648` derives the signal list as the text after the **last
   quote character**. For a bare-function handler -- `trap cleanup EXIT` -- there is no quote, so
   `sig` stays empty and `has_exit` is false: the line is neither flagged by `combined` mode nor
   registered in `file_has_exit`, so `no-hup` mode cannot report the file either. **Two live sites
   are in that form**: `evals/run-eval.sh:276` and `bin/tests/wave6-smoke.sh:37`. Decisive:
   the historical CA-482 regression at `wave6-smoke.sh` **was** the unquoted form (`:34`'s comment
   describes the pre-fix line as `trap cleanup_wave6 EXIT INT TERM HUP`), so re-introducing it today
   passes silently while the same bug written *with quotes* is caught -- a one-character difference
   decides whether the tripwire fires.
2. **RETURN-only traps are invisible** (`sig = " RETURN"`, `has_exit` false) -- which is exactly why
   G4/CA-544 survived a green sweep that names `bin/*` in scope.
3. **The convention's third clause is never pinned (L3)**. `bin/edm-state:687-691` states that
   INT/TERM/HUP must *terminate* after cleanup; the awk never inspects a trap **body** for `exit`.
   So the cleanup-then-resume bug still passes when split across two statements.
4. **Clause 2 is per-file, not per-resource** -- `file_has_hup[FILENAME]` is set by any HUP trap
   anywhere in the file.

Both positive controls (`:9687`, `:9694`) use the quoted form, so they prove the checks are not
vacuous but never probe these boundaries.

**Fix**: parse the signal list **positionally** (strip `trap`, drop a quoted handler if the next
token opens a quote, else drop exactly one bare token, then parse the remainder); add a third mode
requiring every INT/TERM/HUP trap body to contain `exit` (allowing indirection when the named
function itself contains `exit`); treat RETURN as EXIT-class for `no-hup` registration; add one
positive control per shape (unquoted-combined, RETURN-only, two-statement-without-exit).

**Verification**: the three new controls turn red when the corresponding predicate is removed;
`_ca481_sweep` now flags `bin/edm-state:5341` before G4 is fixed and passes after.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G4 (P2, lenses L5 + L7 -- multi-lens): CA-544 -- the plugin's last RETURN-only cleanup trap

Two lenses filed this independently on the same line with the same fix; merged (L5-001 high
confidence, L7-11-002 medium).

**Problem**. `bin/edm-state:5341` is `trap 'rm -f "$_pxt_ignfile"' RETURN` -- RETURN only.
`_pxt_ignfile` is created at `:5340` inside `pattern_extract_titles`, and `bin/edm-state:54` is
`set -euo pipefail`, so an errexit abort inside the function (the three unguarded `awk` calls at
`:5349`, `:5360`, `:5382`) terminates the process **without firing the RETURN trap** -- bash routes
errexit to exit and runs EXIT traps only. An INT/TERM/HUP during `awk` does the same. The variable is
`local` at `:5339`, so no process-wide EXIT trap could reference it either.

**The sibling is the proof**: a whole-tree grep finds exactly two RETURN traps -- this one and
`evals/tiering-matrix.sh:158` -- and the latter is the **fixed** form, whose own rationale at `:148`
reads verbatim "RETURN-only leaked `$tmp` on a die (exit 2, no RETURN) or a SIGINT mid-self-test."
That is a description of this site. CA-014 identified the shape, CA-481(a) converted the other site
**this round**, and this one was never swept.

**The consistency concern is the pin, not the leak** (L7): CA-481(c)'s sweep cannot see this site in
either arm -- `combined` needs one statement pairing EXIT with a real signal (a bare RETURN pairs
nothing), and `no-hup` is file-granular while `bin/edm-state` installs HUP traps at `:695`, `:1510`
and `:6081`. The sweep was landed because the convention was enforced nowhere, and the one
non-conforming site is the one its granularity exempts -- the same all-but-one shape as CA-496,
CA-231, CA-270, CA-531. That gap is G3/CA-541.

**Fix**: mirror the sibling --
`trap 'rm -f "${_pxt_ignfile:-}"' RETURN EXIT`, plus `INT`/`exit 130`, `TERM`/`143`, `HUP`/`129`.
The `${_pxt_ignfile:-}` guard is required for the reason `tiering-matrix.sh:150-153` documents (the
trap is process-wide, so a second firing at EXIT can occur after `local` has left scope and a bare
expansion would trip `set -u`). Both call sites (`:5541` process substitution, `:5654` command
substitution) run the function in a **subshell**, so an EXIT arm is correctly scoped. **Check the
`:5554` call path for `with_state_lock` nesting** (`_save_traps`/`_restore_traps` bracketing) before
applying.

**Verification**: after G3 lands, `_ca481_sweep`'s new RETURN-names-EXIT predicate passes on
`bin/edm-state`; `bash plugins/edm/bin/tests/run-all.sh` green.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G5 (P2, lens L2): CA-537 -- residual of CA-490; the CA-452 partial-run exit-4 block is now unreachable

**This is CA-490's outstanding `spec_swept` obligation**, which is why CA-490 is recorded
`spec_swept: no`.

**Problem**. `.gitlab-ci.yml:859-863` (`if [ "${RUN_EVAL_EC:-0}" -eq 4 ]` -> `exit 4`) was
load-bearing before CA-490 and is now structurally unreachable. Trace with `RUN_EVAL_EC=4`:
(a) missing `scores.json` -> `:853-855` exits 1, never reaches `:859`; (b) present -> post-CA-490
the `complete != "true"` refusal at `edm-compare-eval:71-75` fires **first**, so `rc=2`
unconditionally (the stub's `complete:false` is preserved, not repaired --
`score-artifacts.sh:646`, `:659-660`); (c) `rc=2` hits the `*)` arm at `:851`, which runs
`exit "$rc"`. The only non-exiting arms are `0)` and `3)`, and **both require `complete: true`**,
i.e. `RUN_EVAL_EC != 4`.

Three consequences: the documented partial signal silently changed from exit 4 to exit 2; the
diagnostic pointing an operator at `run.json` / the stub `scores.json` in the artifacts never prints;
and `:808`'s comment ("The job still fails at the end either way") now describes a path that cannot
execute -- the same defect class CA-490 was itself filed for, one level up.

**Fix** (preferred, keeps the documented exit-4 signal): stop exiting inside the `*)` arm -- record
`CMP_EC="$rc"` and let the final block own the exit, preferring 4 over 2 when `RUN_EVAL_EC=4`.
Minimum acceptable: delete `:859-863`, re-word `:801-808` and `:857-858` to state that a partial run
now fails at the comparison step with exit 2, and move the artifacts pointer into the `*)` arm's
message. Either way, add one assertion pinning the job's partial-run exit code.

**Files affected**: `.gitlab-ci.yml`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G6-G8 (P2, lens L9): the SRD/ticket sweep-debt cluster -- CA-554, CA-555, CA-553

Three findings, one theme: **remediations landing in the ticket pack without sweeping the SRD, and
one landing commit shipping its own debt** -- precisely the class `spec_swept` (CA-416/CA-514) exists
to enforce, now recurring inside the commits that implemented it.

- **CA-554** (residue of CA-106): D62's route-(b) boundary is recorded in `decisions.md:71`,
  `tickets/epics/03:579-583`/`:616-628` and `tickets/README.md:638` -- but **not in `srd.md`**.
  `srd.md:1749-1774` (EDMV3-28) is byte-unchanged: `Must Have`, six unchecked ACs, no D62 or
  EDMV4-T05 pointer. The requirements baseline still asserts an in-scope undelivered Must Have that
  three other artifacts say is out of scope. Same shape as CA-509, which was closed by taking the CR
  route; the CR route was not taken here. **Mitigating (why P2)**: D62 is an explicit human gate
  decision that enumerated its own scope and did not include an `srd.md` edit, so the divergence is
  documented rather than silent. **Fix**: a CR9 row plus a one-line boundary note under EDMV3-28
  naming D62 and EDMV4-T05.
- **CA-555** (CR8's + D61's own sweeps): `srd.md:12` still reads `Last Updated | 2026-07-26` against
  a 1.4.0 row dated 2026-08-21; `srd.md:16` still describes `decisions.md` as "(D1-D16)" when it runs
  to D62; `srd.md:1769-1771` (EDMV3-28 AC5) still requires the baseline README to state that the
  **five** dimensions are proxies although D61 authorized **six**. **Fix**: one editing pass --
  refresh `:12`, drop the numeric range at `:16` in favour of naming the file so it cannot go stale
  again, and correct `:1769-1771` citing D61. Land the AC5 half in the same CR as CA-554.
- **CA-553** (AC14's own landing commit): AC14's Verify cites `wave7-smoke.sh:8755-8910`, but the
  `spec_swept` block begins at `:9339` (banner `:9420`, branches `:9446`, `:9457`, `:9473`, `:9484`,
  `:9496-9505`) and there is **no `spec_swept` token in 8755-8910**; and T28 now carries **two
  contradicting AC-band notes** (`:613-615` says 14, `:627-629` says 13 and claims the count is
  "Recorded in the README sizing section", making `tickets/README.md`'s sizing row a likely third
  stale site -- **not verified this round**, declared as an L9 coverage gap). **Fix**: cite the
  banner **string** rather than line numbers (they drift on every insertion), delete the
  Technical-Notes duplicate, and sweep the README sizing row in the same change.

**Verification**: `grep -n 'D1-D16\|2026-07-26' SRD/edm/EDMV3__prompt-streamline/srd.md` returns
nothing; `grep -c 'five dimensions' srd.md` is 0; `grep -n '13 acceptance criteria'
tickets/epics/04-structured-findings.md` returns nothing; AC14's Verify command runs as written.

---

### G9 (P2, lens L10): CA-556 -- residual of CA-513

CA-513's P1 is genuinely closed: the fence **classifier** is now single-sourced
(`ignored_line_set` called once at `:5342`). What remains is the **consumption** boilerplate --
`BEGIN { while ((getline _pxt_ln < ignfile) > 0) ... skip[_pxt_ln] = 1 }` plus
`(NR in skip) { next }` copied byte-identically at `:5350-5351`, `:5361-5362`, `:5383-5384`. No
divergence today; the finding is extension cost plus an untested surface. Adding the sixth audit type
that `bin/edm-state:5313` and `docs/audit-patterns/README.md:71` both contemplate means a fourth
hand-copy, and one that drops `(NR in skip) { next }` **silently re-opens CA-476/CA-513 for that type
alone**. The CA-513 regression block (`wave7-smoke.sh:4277-4315`) drives the **code arm only**; the
`srd` (`:5360-5369`) and `qc` (`:5382-5391`) arms have no indented-fence and no long-fence case at
all, so "every arm honours the shared ignore set" is verified for **1 of 3** arms.

**Fix** (cheapest sufficient): add a `count_matches_strict` pin asserting the `(NR in skip) { next }`
occurrence count equals `PATTERN_AUDIT_TYPE_ENUM_LIST`'s word count minus the two names in the
`ticket|test-coverage` early-return arm -- `wave7-smoke.sh:1217-1228` is already exactly this shape.
Alternatively extract a prelude-prepending wrapper. Independently: extend the CA-513 fixture to drive
the `srd` and `qc` arms with an indented fence.

---

### G10 (P2, lens L7): CA-549 -- residual of CA-535, and a self-correcting error chain

`skills/orchestrator/SKILL.md:7` now carries the prescribed comment:
`# quoted: the | here is a literal pipe, not the YAML block-scalar indicator -- unquoted it would be
parsed as one`. **The rule is wrong, and two siblings visibly contradict it.**

`|` is a YAML block-scalar indicator only in the **first character position** of a value. All three
`argument-hint` values in the family that contain `|` begin with `<`, which is not an indicator
character, so all three are ordinary plain scalars and `orchestrator:7`'s quoting is **optional**.
Live proof in the same directory: `test:7` (`<PREFIX> [--fill-gaps | --skip-scaffold]`) and
`metrics:7` (`<PREFIX|--all|--calibrate> ...`) have shipped **unquoted** through eleven audit rounds
and through `validate:manifest`'s frontmatter parse. The genuinely-forced case elsewhere in this repo
is `plugins/git/skills/commit/SKILL.md:5`, where the constraint is the `': '` in
"optional type override: feat|fix|...", not the pipes.

**Why it matters**: this is shipped prompt-surface text in a plugin whose thesis is that a documented
convention is a contract, and the comment added to make one exception read as an exception now makes
two **conforming** siblings read as bugs. The error chain is fully traced: round 10's L7-003
write-up -> ledger entry CA-535 -> copied verbatim into the file. CA-535's ledger entry has been
**amended with an explicit retraction** as part of this round's merge.

**Fix** (preferred): drop the quotes at `orchestrator:7` so all three siblings agree (12 of 14 sites
are already unquoted), keeping a comment that names the **real** constraint -- quote only when the
value starts with a YAML indicator character or contains `': '`.

---

### G11-G14 (P2, lenses L3, L8): the eval-driver and credential-boundary cluster

- **CA-540** (L3, residual of CA-511): `inner_worst_case_secs=$((PHASE_TIMEOUT_SECONDS * 3 + 60))` --
  the `3` is a literal with no coupling to the three `invoke_claude` call sites (`:542`, `:575`,
  `:613`). **The pin makes it worse**: `wave7-smoke.sh:8975-8976` asserts the **literal source
  string** and `:8982-8986` re-implements the formula with its own hardcoded `* 3`. Add a fourth
  phase -- exactly the change `.gitlab-ci.yml:778-780` warns about in prose -- and the guard still
  computes 8160 against `CI_JOB_TIMEOUT=9000` and proceeds while the real worst case is 10860s;
  GitLab kills the job at 150m and the trailing `script:` steps never run, bypassing scoring,
  `edm-compare-eval` **and CA-452's partial-run handshake precisely when the run was partial**.
  **Fix**: derive the multiplier from a single enumerable source (e.g.
  `EVAL_PHASES="plan srd audit-srd"`) that both the call sites and the arithmetic read, and change
  the wave7 case from a literal-string grep to a computed assertion, with a stub-fourth-phase
  positive control.
- **CA-550** (L8): `EDM_EVAL_MAX_BUDGET_USD` at `run-eval.sh:460` is the **only** `EDM_EVAL_*`
  numeric knob with no validation, and it flows unchecked to `--max-budget-usd` at `:492`. The
  sibling timeout knob at `:423-433` **is** validated with an exit-2 `case` precisely because the
  driver runs without `set -e` (CA-444); `CI_JOB_TIMEOUT` and `KEEP_RUNS` likewise. The omission is
  documented as a *known state* at `CLAUDE.md:1033` rather than fixed -- documenting that a
  validation is absent is not a rationale for its absence, so Filter clause 1 does not clear it.
  Failure direction is undetermined and that is the finding. **Fix**: apply the CA-444 pattern
  verbatim beside the default, plus one smoke case asserting exit 2 on a non-numeric value.
  **Secondary (L6 axis, cross-referenced not double-filed)**: `run-eval.sh:36`/`:406` call this a
  **per-phase** ceiling while `CLAUDE.md:1033` calls it **per-run** -- a 3x difference in what an
  operator thinks they capped.
- **CA-551** (L8): `run_with_timeout` (`:316-318`) and `cleanup` (`:260-263`) signal only
  `$CURRENT_CHILD_PID`, never the process **group**. The direct-child case was analysed and closed
  at `:465-470`; the **grandchild** case is addressed nowhere. `claude -p` holds
  `Bash(edm-state *)`, `Bash(edm-init *)`, `Bash(edm-validate-prefix *)`, `Bash(jq *)` (`:421`), so
  its Bash-tool children inherit `ANTHROPIC_API_KEY` and survive the 124-timeout and every
  INT/TERM/HUP -- then `cleanup` `rm -rf`s `$SCRATCH_DIR` (`:265-267`) out from under them. On CI the
  container masks it; the **documented developer path is a workstation**, where the orphan persists
  for the login session. This is the only place in the plugin where a process holding a live
  credential can survive its supervisor. **Fix** (bash-3.2 safe): `set -m` around the `&` at `:311`
  (`set +m` after capturing `$!`), then `kill -TERM -"$pid" || kill -TERM "$pid"` and the same for
  `-KILL`, in both `run_with_timeout` and `cleanup`; add a `sleep 300 & wait` stub smoke case
  asserting `kill -0` on the grandchild fails after 124.
- **CA-552** (L8, low confidence, **re-raise of a lost round-8 item**): `eval:nightly` publishes the
  entire `plugins/edm/evals/runs/` tree `when: always`, `expire_in: 30 days`, no `exclude:`, no
  redaction -- including `raw/<phase>.stderr.log` and `raw/<phase>.json` (`run-eval.sh:480`). GitLab
  masks variables in **job logs only**; artifacts are never masked. **Boundary stated explicitly**:
  L8 traced every write into the run directory (`:157`, `:162`, `:480`, `:725`) and found **no site
  that writes the key to a file today** -- this is an exposure surface, not a demonstrated leak.
  Filed with an ID specifically so it is not lost a third time. **Fix**: narrow `paths:` to
  `run.json` and `scores.json`, or add
  `exclude: ["plugins/edm/evals/runs/*/raw/*.stderr.log"]`; if raw stderr is wanted for triage, add a
  redaction pass and say so in the job comment.

---

### G15-G18 (P2, lens L11): the wiring cluster

- **CA-558**: `SRD/edm/EDMV3__prompt-streamline/qc/qc-shard-01.md` and `qc-shard-02.md` are **real
  committed artifacts** (named by `qc/qc-summary.md:5`) that match **neither** merge glob at
  `skills/implement/SKILL.md:122`, while `bin/edm-state:2638`'s wider `qc/qc-shard-*.md` still accepts
  them for phase-6 completion -- and `:2642`'s own die text enumerates only the two post-CA-473
  prefixes. Any merge re-run silently drops both files' verdicts. **Fix**: rename to
  `qc-shard-impl-01.md` / `qc-shard-impl-15.md` (they are per-range reports), note the rename in
  `qc-summary.md:5`, then either narrow `:2638` to the two documented prefixes or amend `:2642` to
  admit the bare form. Sequence with G1/CA-515.
- **CA-559**: `bin/edm-check-grants`'s grant-without-instruction (negative) direction covers sources
  1-3 (agents) only; `:35-37` states source 4 (skills) is positive-only, so skill **over-grants** are
  structurally invisible. Two live instances: `skills/verify-runtime/SKILL.md:8`'s `Bash(mkdir *)`
  (see CA-560) and `skills/implement/SKILL.md:8`'s `TodoRead`, the only occurrence of that token in
  the plugin -- **cited as evidence, not double-counted**, because L1 already owns it. **Fix**: extend
  the negative direction to source 4, **warning-only** exactly as the agent-side direction is
  (`:31-32`), so it never changes the exit code.
- **CA-560**: `skills/verify-runtime/SKILL.md:80` writes `${INIT_DIR}/post-deploy/verification.md`
  with **no `mkdir -p`**, though `:8` grants `Bash(mkdir *)`. Both sibling write-into-new-subdir
  surfaces instruct it (`agents/edm-qc-auditor.md:87`, `skills/code-audit/SKILL.md:62`), so this one
  depends on an unstated host behaviour. **Fix**: add `mkdir -p "${INIT_DIR}/post-deploy"` as the
  first action of step 4(g). Removes one instance from CA-559's list at the same time.
- **CA-561**: `evals/fixtures/tiny-svc/src/api/routes.js:10` registers `GET /health` -> `handleHealth`,
  which has zero callers (`server.js:19-24` dispatches only `handleWebhook`). The fixture has an
  explicit convention of annotating deliberate dead wiring (`queue.js:5-7`, `processor.js:21-22`);
  this is the one piece carrying no note. Scoring impact is nil (dimension 6 measures recall of the
  six known gaps; extras are not penalised), so this is fixture maintainability. **Fix**: a two-line
  comment in the established form, or add the dispatch branch to `server.js`.

---

### G19-G22, G42 (P2, lenses L3, L4, L5): the runtime-hygiene and test-integrity cluster

- **CA-542** (L3): `bin/edm-init` runs `set -euo pipefail` with **no trap**, and its scaffold is
  non-atomic (`:130`, `:133`, `:134-144`, `:146-159`, then `edm-state init` at `:165`). A failure or
  Ctrl-C at `:165` leaves `$DIR`, `explorers/`, `decisions.md` and (in three of five modes)
  `code-audit/` with **no state file**; the retry then hits `[[ -d "$DIR" ]]` at `:125` and dies with
  "run `edm-state get $PREFIX` to inspect" -- **a hint that cannot work**, because the state file the
  guard implies was never written. **Explicitly not a reopen** of the `:125`-to-`:130` TOCTOU, which
  round 10 adjudicated Not Actionable; this is the partial-failure axis and L3 scoped it so.
  **Fix**: canonical four-arm trap after `:130` removing `$DIR` only if this invocation created it and
  has not reached the success point, cleared once `edm-state init` returns; or make `:126`'s
  diagnostic distinguish the two cases and name the `rm -rf`.
- **CA-543** (L4): `wave6-smoke.sh:817` -- the CA-426 stream-separation pin captures stdout with
  `2>/dev/null` and asserts only stdout and the exit code, so nothing asserts the zero-rounds warn
  reaches **stderr** at all. Delete the warn or move it to stdout and the pin stays green: it proves
  half of a two-stream contract. **Fix**: capture stderr separately and assert the warn is present on
  stderr and absent from stdout. Land with CA-492 (the missing boundary case on the same fixture).
- **CA-545** (L5): `wave6-smoke.sh:4929-4930` are the only two `mktemp` sites in that file not rooted
  under the suite's `${TMP}`; the interrupt window is real (`:4932-4937` races two background
  lock-contending `edm-state` processes and waits; `:4945-4946` `cat`s under `set -euo pipefail`
  before the tail `rm -f` at `:4960`). The same file states the nest-under-`$TMP` rule at `:463-464`.
  **Fix**: two one-line template changes to `"${TMP}/..."`, keeping `:4960` as a fast path.
- **CA-546** (L5): `timing.sh:243`'s `: "${DIR:=$(mktemp -d ...)}"` mints a 50-initiative tree that
  `_timing_cleanup` never sweeps. The exclusion rationale at `:40-41` covers only the
  caller-supplied case -- but `:=` fires **only when `--dir` was omitted**, so the rationale documents
  the branch that creates nothing and not the branch that does. **Fix**: set `_TIMING_OWNS_DIR` in
  the `:=` branch and sweep `DIR` guarded on it, preserving the carve-out exactly.
- **CA-171 -- UPGRADED FROM NOTED TO P2** (L5): five untrapped temp files in
  `harness-smoke.sh` (`:45`, `:63`, `:115`, `:139`, `:191`), the file's first trap being at `:265`.
  The upgrade trigger is `:64`'s `_ac2_sleep_fn() { pwd > "$_ac2_pathfile"; sleep 5; }`, polled by
  `:73` -- the widest signal-deliverable window in the test tree, with `_ac2_pathfile` unhandled
  across it, so a Ctrl-C leaks with near-certainty rather than by unlucky timing. Round 10's holding
  rationale ("assertion helpers never exit early") addresses the errexit path only and says nothing
  about the signal path. Consistency forces the filing: CA-481(b) was filed and fixed over a
  **one-statement** window and CA-495(b) over subshells that **did** carry tail removals.
  **Fix**: one four-arm trap after `:45` covering all five by name with `${var:-}` guards, or mint a
  suite-level `$TMP` root and nest all five inside it.

---

### G23-G27 (P2, lenses L2, L6, L10): the documentation and dead-code cluster

- **CA-547** (L6, merges L6's P2-1 and P2-3 -- same `file:line`, same root cause):
  `plugins/edm/CLAUDE.md:1057` says the blocking `lint:file-type-ban` job sums `plugins/edm/evals/`
  at "~134KB and therefore over budget at HEAD" (i.e. **red on every MR**), while
  `evals/fixtures/tiny-svc/README.md:38-46` and `evals/README.md:294` both assert compliance
  (i.e. **green**). At most one is true, and a contributor's belief about whether the plugin merges
  depends on which file they opened. The `~134KB` figure is additionally a hand-maintained measured
  quantity with **no tripwire** -- the exact failure mode the same file refuses at `:803`.
  **Fix**: single-source the verdict on the job's own emitted line, delete the standing assertion
  from all three prose sites, and replace the figure with the reproduction command at
  `evals/README.md:297-298` or pin it G25/CA-342-style. If the sum truly exceeds 100KB, say so and
  name the resolution (narrow the sum per EDMV3-T22 AC3, or raise the constant).
- **CA-548** (L6): `evals/fixtures/tiny-svc/README.md:38-39` asserts a **fixture-tree** measurement
  against the **whole-tree** budget, while `:41-43` of the same bullet correctly describes the
  enforcement as `git ls-files -- plugins/edm/evals`. One bullet both distinguishes and collapses the
  two scopes (CA-463). Filed separately from CA-547 because it survives a CLAUDE.md-only fix.
  **Fix**: the one-sentence rewording given in the ledger entry.
- **CA-557** (L10): `score-artifacts.sh:163-181` (`--describe`) re-types all six `DIM_NAMES` as prose
  literals -- the one in-code second copy of a canonical list at `:147`, alongside the docstring
  (`:44-58`), two hand-index-aligned arrays (`:670-671`) and two READMEs. `bin/edm-state:799-803`
  documents the opposite convention and six constants there now obey it (CA-503, CA-533, both fixed
  this round). **Weight honestly reduced**: the count is pinned at six (`wave7-smoke.sh:648`, `:686`),
  `--describe`'s names are individually pinned (`:858`, `:863`), and `dimensions_scored` is read from
  the data -- **no live bug is reachable**. Filed for convention consistency only.
  **Fix**: interpolate `DIM_NAMES` members into `--describe`'s numbered paragraphs. Leave both
  READMEs and the docstring as prose. The six per-dimension scorers are **data and logic, not
  duplication**, and are explicitly not the finding.
- **CA-538** (L2): `run-all.sh:145-148` -- `:146` and `:148` are byte-identical `printf` calls, so the
  condition decides nothing for the statement it guards (the CA-054 class, which this project has
  filed and fixed). **Fix**: hoist the `printf` above the `if` and reduce to a one-armed `if` for the
  failure-only extras at `:149-152`. Output unchanged byte-for-byte.
- **CA-539** (L2): `edm-mermaid-rules.awk:96`'s bare-keyword guard is provably inert -- such a line
  contains no `;`, no span character and no `->`, so it reaches `return 0` at `:117` regardless.
  Distinguish from `:95`, which **is** load-bearing and has a regression fixture. Sixth member of a
  class filed and resolved six times (CA-140, CA-202, CA-260, CA-309, CA-362, CA-519).
  **Fix by merging, not deleting outright**: relax `:95` to
  `^(classDef|style|linkStyle)([[:space:]]|$)` and delete `:96`.

---

## Decisions / Non-Findings

These items were flagged, observed, or raised this round and determined **Not Actionable**. Future
audits should **not** re-investigate them.

### Filtered this round

1. **L1 -- `bin/edm-state:5772`'s `grep -c .` in a command substitution** -- Filter 2: the `[[ -z ]]`
   branch at `:5766` guarantees non-empty input; documented at `:5756-5764`.
2. **L1 -- CA-516's document-reconciliation half left undone** -- Filter 1: the fix took the
   accept-both-shapes branch, so two documented shapes is now the intended contract.
3. **L1/L10 -- `.gitlab-ci.yml:355`'s `COUNT` vs `EXPECTED_COUNT` tautology** -- Filter 2: stated
   deliberately as a structural invariant at `:310-311`; CA-518 already declined to file it.
4. **L10 -- `lint:hooks-shell` writes its jq select-chain three times** -- self-guarded: three
   deliberate variants of one walk, narrowing documented at `:323-327`, divergence caught by the
   `:356` cross-check.
5. **L2 -- `.gitlab-ci.yml:853-855`'s scores.json-missing else arm** -- Filter 1: a cross-process
   postcondition check on a separate script; also load-bearing to CA-537's path analysis.
6. **L2 -- `.gitlab-ci.yml:849`'s `0)` arm** -- Filter 1: environmentally unreachable only until the
   wave-A baseline is captured (D23/CA-106).
7. **L2 -- `run-eval.sh:342-351`'s G45 auth probe** -- Filter 1: dead on the automated path, live
   locally on subscription auth, the case it was written for. Consequence recorded: the `+60` term in
   both timeout arithmetics is a phantom where the CA-511 guard is live, erring conservatively.
8. **L2 -- `_harness.sh:283-286`'s unhashable arm** -- Filters 1+2: needs both `shasum` and
   `sha256sum` absent, which no environment this suite runs in produces; it is CA-394's own remedy.
9. **L2 -- `bin/edm-state:4837-4839`'s second "invalid JSONL" refusal** -- not dead: preempted for the
   failure its message names but reachable for a jq evaluation error. If touched, differentiate the
   message rather than removing the arm.
10. **L2 -- `bin/edm-init:146-159`'s byte-identical `standard|iac|data-ml` and `mini-srd` arms** --
    both arms execute and each comment carries distinct mode documentation. Recorded, not filed.
11. **L3 -- `bin/edm-init:125`-to-`:130` TOCTOU** -- honouring round 10's Non-Finding 9. CA-542 is
    scoped to the partial-failure axis and does not reopen it.
12. **L3 -- `_edm_reclaim_stale_lockdir` derives its stale-aside name from `$$`** (`:1195`) -- safe
    because `_EDM_TRAP_DEPTH` is process-global. Change it in the same commit if cross-lockbase
    nesting is ever made legal.
13. **L3 -- `bin/edm-state:1407`-to-`:1507` untrapped lock window** (round 10's N1) -- now
    **self-healing** via CA-480's hoisted age-gated reclaim. Not filed.
14. **L3 -- CA-294/CA-375 lock give-up budget asymmetry** -- **RESOLVED, not standing**: `:1202-1217`
    single-sources both backends from `EDM_STATE_LOCK_WAIT_S`. Round 10's N9 description is stale and
    must not be carried forward again.
15. **L3 -- CA-479's mtime tie-break falling back to glob order** -- the warning still names every
    candidate, so the ambiguity is never silent.
16. **L4 -- `wave7-smoke.sh:2861`'s t44_block awk extraction** -- fails in the safe direction.
17. **L4 -- `wave6-smoke.sh:820`'s substring check on the P2-count message** -- substring containment
    is the right semantic for a message-content check.
18. **L5 -- CA-480 is not an L5 finding** -- both `.lockd` and its `.stale.$$` aside are ignore-covered,
    so a bricked lockdir never reaches `git status`. Impact is availability (L3), not hygiene.
    Recorded so the round does not double-count it.
19. **L5 -- CA-169's never-unlinked flock lockfile** -- **must stay unapplied**; mutual exclusion is
    inode-keyed. Now content-anchored-pinned at `wave7-smoke.sh:5876-5889`. Do not "fix".
20. **L5 -- `edm-state update-patterns` mutating tracked plugin files** -- intended Living-Library
    design; staging path is ignore-covered.
21. **L5 -- `run-eval.sh --out DIR` pointed at an unignored in-repo directory** -- operator choice,
    documented, with an explicit `EDM_EVAL_PRUNE_EXPLICIT_OUT` opt-in.
22. **L6 -- `CLAUDE.md:807` "the scorer itself never compares"** -- deliberate simplification;
    `--compare` delegates to `bin/edm-compare-eval` (CA-383) and says so.
23. **L6 -- `CLAUDE.md:799` "39 subcommands"** -- verified accurate against 39 `cmd_*()` definitions.
    (Unpinned, but that is an L7 durability concern, not an inaccuracy.)
24. **L7 -- `bin/edm-lint-staged-artifacts`'s inverted exit-code contract, mixed diagnostic prefixes,
    POSIX `[ ]` tests, and bare `help` token** (N1-N4) -- Filters 1/2/3; the last stands as **CA-289**
    with an explicit do-not-re-file disposition.
25. **L7 -- `.gitlab-ci.yml:293` and `:632`'s EXIT-only traps** -- Filter 3: container-ephemeral YAML
    job-script fragments, deliberately outside CA-481's scope. The count went 1 -> 2 **by design**;
    do not treat `:632` as a new regression.
26. **L8 -- `bin/edm-state:1094-1096`, `:1085`, `:1809`** -- correct **residuals** of the CA-500 fix,
    not gaps in it (no-git-toplevel case documented in place; the vendored-settings shape is
    unreachable in this tree; the second `2>/dev/null` only avoids a duplicate warning).
27. **L8 -- `.gitlab-ci.yml:565`'s untrapped `LIST_FILE`** -- CA-493 residual, inert in an ephemeral CI
    container with a job-scoped TMPDIR. Two-line fix if sibling consistency is wanted; not a finding.
28. **L8 -- `CLAUDE.md:927` sanctioning `#!/bin/bash`** -- real doc/enforcement divergence, but the
    actionable half is L6's axis; recorded as a cross-reference, not double-filed.
29. **L8 -- ~15 heredoc scratch stubs with `#!/bin/bash`** in `wave7-smoke.sh` -- Filter 1: test-only
    fixtures that fail loudly on a host with no `/bin/bash`.
30. **L8 -- `tiny-svc/config/settings.json:5`'s `billingApiKey`** -- Filter 1: a deliberately planted,
    self-labelling fake credential that is one of dimension 6's ground-truth gaps.
31. **L8 -- `export ANTHROPIC_API_KEY=sk-...` in operator docs** -- placeholder, not a value.
32. **L8 -- `CLAUDE.md:391`, `:399` absolute developer paths** -- provenance prose, never resolved by
    any code path. Genericizing is an L6 tidiness argument.
33. **L8 -- `.gitlab-ci.yml:513`'s floating `bash:3.2` tag** -- CA-111: documented,
    explicitly-authorized exception with a stated must-pin-before-first-live-use condition.
34. **L8 -- `edm-lint-staged-artifacts:147`'s `for p in $prefixes`** -- intentional unquoted split;
    every token is clamped to `^[A-Za-z0-9_-]+$` upstream and both calls pass `$p` as argv.
35. **L8 -- `monitors/monitors.json:4`'s bare PATH-resolved command** -- no arguments, no
    interpolation, no injection surface.
36. **L10 -- `wave7-smoke.sh:7985`'s hand-rolled `infence` toggler** -- Filter 2: test-side, and a
    missed indented fence **widens** rather than narrows the scan. Now the only copy in the tree
    (CA-513 removed the other three) and the cheapest follow-on if anyone wants the idiom gone.
37. **L10 -- `build_dims_json` vs `build_skipped_json`** (`score-artifacts.sh:580-610`) -- mechanical
    scaffold duplication; any separator bug fails a jq parse immediately.
38. **L10 -- `hooks.json` five-hook duplication** -- re-checked for drift, none found; CA-376's
    rationale (JSON has no include mechanism) holds.
39. **L10 -- the `qc-shard-impl-`/`qc-shard-pass-` namespace prose across six surfaces** -- the
    **duplication** is the accepted prompt-surface pattern; it is the **divergence** within it that is
    G1/CA-515.
40. **L10 -- `run-eval.sh:474-588`'s three phase blocks** -- CA-283 unchanged; prescribed `run_phase`
    extraction still the right fix; no escalation.
41. **L10 -- `bin/edm-state`'s `now_utc()`, `SPEC_SWEEP_DEBT_FILTER`/`BLOCKING_FILTER`,
    `_edm-lint-lib.sh`'s shared home** -- swept and correctly DRY; not filed.
42. **L11 -- `monitors/monitors.json`'s arm trigger** -- Filter 1: the event source
    (`on-skill-invoke:implement`) is the Claude Code host, external to this codebase (D24).
43. **L11 -- `evals/tiering-matrix.sh` has no production caller** -- Filter 3: documented as
    intentional pending the wave-A baseline (D23/D28, "NOT yet matrix-derived").
44. **L11 -- the eval comparison tripwire is un-armed at HEAD** -- by design; `evals/baseline/` holds
    only `README.md`, exit 3 maps to a reported non-pass. Un-armed is the honest state, not dead
    wiring.
45. **L11 -- `skills/implement/SKILL.md:8`'s `TodoRead` grant** -- L1-owned (pass-10
    `lens-L1.md:154`); cited as evidence for CA-559, deliberately **not** double-counted.
46. **L5-006 -> CA-562, DEMOTED P2 -> NOTED** -- `wave7-smoke.sh:6843`'s `.gitignore` coverage
    assertion omits the `findings-ledger` lockbase. Single lens, low confidence, **no live exposure**
    (coverage holds by construction). Retained as NOTED per the no-finding-is-dropped rule and the
    CA-517/CA-535 precedent; the latent `*.lock.<suffix>` pattern asymmetry is recorded in the entry
    so a future round need not re-derive the reachability argument.

### Standing dispositions re-confirmed and corrected

47. **CA-459 / D60** -- `assert_count_with_control` still absent, 66 hand-rolled sites, confirmed by
    L4 and L10. **D60 is the disposition of record**; excluded from re-filing. Remains `open` P2 in
    the ledger (P2s do not block convergence) as confirmation only.
48. **CA-521 -- RE-DISPOSITIONED OPEN P2 -> NOTED** on L3's explicit recommendation. The
    index-vs-worktree gap is unchanged in code, but the round-10 plan's own stated minimum landed at
    three surfaces (script `EDM-HELP:25-31`, `CLAUDE.md` hooks row, and a **test-pinned case with a
    positive control** at `wave7-smoke.sh:7314-7368` carrying an inline instruction to flip the
    assertion when the full fix lands), with the blocking `lint:artifacts --all` CI job named as the
    enforcement of record. Filter clause 1 now applies. L3's argument, adopted: *an accepted gap left
    in the open set is indistinguishable from an unaddressed one.*
49. **CA-522's entry text CORRECTED (L2-N15)** -- the round-10 mitigating clause claiming
    `monitors/monitors.json` "is no longer in the tree" is **factually false and has been retracted in
    the ledger**. The file exists at HEAD (`edm-check-vocabulary:103`, `:121` scan it;
    `wave7-smoke.sh:2095`, `:5817` assert against it), independently corroborated by L11-N5, so
    `cmd_watch_impl` was reachable via the host-armed monitor as well as the CLI and the
    dropped-notification window was live in the multi-implementer case. The P2 rating stands and the
    finding **is** fixed (L3 verified `bin/edm-state:3392-3419` plus the `wave7-smoke.sh:8706-8715`
    pin), but one of its two mitigating clauses was wrong and must not be reused.
50. **CA-535's entry text CORRECTED (L7)** -- its YAML rationale ("`|` is a block-scalar indicator, so
    the quoting is required") is **false and has been retracted in the ledger**. The error propagated
    from round 10's L7-003 write-up into this ledger and from there verbatim into shipped prompt text;
    that shipped comment is G10/CA-549.
51. **CA-376's premise CORRECTED (L10, third consecutive round of asking -- now actioned)** -- the
    bundle's stated reason for skipping the `SRD_ROOT` duplication ("the four independent derivations
    have no shared library they could source first") is **false**: all four scripts source
    `bin/_edm-cli-lib.sh`. The count half is now accurate at four (down from five since
    `edm-lint-staged-artifacts` dropped its copy). The duplication remains **not filed** -- four
    copies of a one-line env-var default chain is genuinely low value -- but skip it on the
    **low-value** ground, never on the no-shared-library ground.
52. **CA-130 -- NOTED, eleventh consecutive round, MUST NOT BLOCK CONVERGENCE.** Reported
    independently by L2, L3, L5, L6, L7, L8, L10 and L11. Delivered tool set was again
    Read/Grep/Glob/WebFetch/WebSearch/TaskStop -- **no `Write`, no `Bash`** -- despite the frontmatter
    grant at `agents/edm-audit-*.md:5`. Consequence: **no lens could write either half of its own
    output**; all 22 lens artifacts were returned inline and transcribed by the launching agent
    (`skills/code-audit/SKILL.md` step 8a's fallback is what kept this round's JSONL complete).
    Second-order consequences, recorded because they degrade **evidence quality** and not just
    ergonomics: (a) every FIXED verdict this round is read-derived from HEAD rather than diff-derived
    over `0b2f304`, and **no finding was reproduced dynamically** -- CA-331/CA-377's request that a
    Bash-capable pass run `bin/tests/run-all.sh` immediately before the convergence gate is
    outstanding for a **seventh** round; (b) CA-505 is recorded FIXED on inspection of format strings
    for a fourth round because one command would have settled it by observation; (c) the delivered
    **prompt** was again the stale variant for L7 and L8 (missing `## Scope`, `## Output`,
    `## JSONL Line Format`, `## When this does NOT apply`), so the JSONL schema came from the launch
    prompt's restated fallback per D22 -- though L2 confirms `## Scope` *did* arrive this round, so the
    staleness is intermittent per-agent rather than global. Repository-side half remains **CA-193**.

### Declared coverage gaps (report as unaudited, not clean)

Recorded so a future round does not read silence as a clean verdict:

- **L1**: no fresh-eyes logic sweep of the ~530 lines added to `bin/edm-state` since round 10 outside
  the `pattern_extract_titles` / `cmd_audit_round_complete` / `write_handoff` regions.
- **L2**: `bin/edm-state` outside `:4589-4948`; all `bin/tests/*-smoke.sh` bodies (grep-only);
  `evals/score-artifacts.sh` outside `:636-780` including `cmd_compare`; `.gitlab-ci.yml` outside
  `:700-868`; all `skills/**`, all `agents/*` but its own frontmatter, `docs/**`, both `CLAUDE.md`s.
  Highest-value round-12 targets, in order: the two big smoke bodies, `state_anomalies`
  (`:1706-1956`) and the `update-patterns` family (`:5257-5690`), then `score-artifacts.sh` in full.
- **L3**: `bin/edm-state:1550-3290`, `:3421-4513`, `:5060-5486`, `:5692-6203`; six `bin/` helpers and
  both shared libs; `run-eval.sh` outside `:395-460`; `bin/tests/**` beyond the ranges read; remaining
  `skills/**`, `agents/**`, `docs/**`. CA-027/028/055/062 got no regression check.
- **L4**: no fresh full-file sweep of `wave7-smoke.sh` (~9,600 lines) or `wave6-smoke.sh` for **new**
  L4 classes; `wave3`, `wave4b`, `timing.sh`, `harness-smoke.sh` got no coverage at all.
- **L6**: no full prose sweep of `skills/` or `agents/`; the 134KB-vs-100KB byte total was not
  measured (no Bash).
- **L8**: no file mode was observed and nothing was executed; `skills/**`, `agents/*` and `docs/**`
  covered by targeted grep only.
- **L9**: no full 120-requirement SRD sweep, no full AC sweep of all 11 epics, no repo-wide
  scope-creep sweep, and `tickets/README.md`'s T28 sizing row (CA-553's likely third stale site) is
  unverified.
- **L11**: the `update-patterns` producer/consumer chain and the synthesizer spawn chain were
  re-verified only at the CA-507 pin; `docs/audit-patterns/*` consumer wiring beyond
  `code-audit.md:119`; `run-eval.sh`'s phase-driver wiring.

---

## Rollout Order

### Wave 1 -- unblock the convergence gate (P1 only; must ship first)

Both P1s are independent (different files, different subsystems) and can be done in parallel.

1. **G1 / CA-515** -- sweep the five stale filename copies **and change `wave7-smoke.sh:9388`** in the
   same commit (the test currently pins the bug, so a code-only fix goes red), plus
   `wave6-smoke.sh:2091`. Add the six-way token-equality pin.
   Touches: `agents/edm-qc-auditor.md`, `skills/implement/SKILL.md`, `hooks/hooks.json`,
   `plugins/edm/CLAUDE.md`, `wave7-smoke.sh`, `wave6-smoke.sh`.
2. **G2 / CA-536** -- add the refusal-reason enumeration to `bin/edm-state`'s `EDM-HELP` block, fix
   AC13's doc clause and Verify.
   Touches: `bin/edm-state`, `plugins/edm/CLAUDE.md`, `tickets/epics/04-structured-findings.md`.

After Wave 1, re-run the targeted lenses (below). **The gate can then close if no new P0/P1 appears.**

### Wave 2 -- P2s that are residuals of this round's own fixes (highest value, batch as one commit each)

These are ordered so that dependencies land first.

3. **G3 / CA-541** (the trap sweep's parser + third clause) -- **before** G4, so G4's fix is actually
   pinned by a sweep that can see it.
4. **G4 / CA-544** (`bin/edm-state:5341` four-arm trap). Check `:5554` for `with_state_lock` nesting.
5. **G5 / CA-537** (the `.gitlab-ci.yml` exit-4 block) -- closes CA-490's `spec_swept` debt.
6. **G9 / CA-556** (CA-513's prelude pin + `srd`/`qc` fence fixtures).
7. **G10 / CA-549** (drop the quotes at `orchestrator:7`, correct the comment).
8. **G11 / CA-540** (derive the eval phase multiplier; replace the literal-string pin).
9. **G6-G8 / CA-554, CA-555, CA-553** -- one SRD/ticket editing pass. CA-554 and CA-555's AC5 half
   share a CR (both edit EDMV3-28); CA-553 is a separate file. Verify `tickets/README.md`'s T28 sizing
   row while in there.

### Wave 3 -- P2s grouped by file independence (parallelizable)

- **`evals/run-eval.sh`**: G12 / CA-550 + G13 / CA-551 (same file, one commit).
- **`.gitlab-ci.yml`**: G14 / CA-552 (artifact narrowing).
- **Prompt surfaces / wiring**: G15 / CA-558, G16 / CA-559, G17 / CA-560, G18 / CA-561. G17 before
  G16, since fixing it removes one instance from G16's list.
- **`bin/` runtime hygiene**: G19 / CA-542.
- **Test suites** (independent files, safe to parallelize): G20 / CA-543 + **CA-492** (same fixture),
  G21 / CA-545, G22 / CA-546, G42 / CA-171.
- **Docs**: G23 / CA-547 + G24 / CA-548 (one coordinated commit -- they touch the same budget claim
  from two sides), plus the `CLAUDE.md:927` shebang-sanction cross-reference from non-finding 28 and
  the per-phase/per-run wording from CA-550's secondary note.
- **Dead code / DRY**: G25 / CA-557, G26 / CA-538, G27 / CA-539.

### Wave 4 -- explicitly deferred with rationale

- **CA-459** -- carried as documented debt **D60**. Deferred by standing decision; do not re-file.
- **CA-401** (11 sites), **CA-402**-**CA-405**, **CA-453**, **CA-455**-**CA-457**, **CA-491**,
  **CA-492**, **CA-496** -- the long-standing test-quality set. **CA-496 is fourth-round open and
  should be promoted out of this bucket**: its fix is two lines (add `edm-lint-staged-artifacts` to
  `wave7-smoke.sh:6733`, correct `:6758`'s counts to 13/10), or better, derive the list from
  `${PLUGIN_DIR}/bin/*` the way `wave7-smoke.sh:5472-5479` already does for CA-501, which retires the
  class. **CA-518** likewise is one scratch-fixture case away from closed.
- **CA-562** (NOTED) -- land opportunistically with any other `.gitignore` or lockbase work.

---

## Verification Plan

### Static / syntax

```bash
# from the repository root
bash -n plugins/edm/bin/edm-state
for f in plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do
  case "$f" in *.awk|*.txt) continue ;; esac
  bash -n "$f" || echo "SYNTAX FAIL: $f"
done
shellcheck -S warning plugins/edm/bin/edm-* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
jq -e . plugins/edm/hooks/hooks.json > /dev/null
jq -e . plugins/edm/monitors/monitors.json > /dev/null
jq -e . plugins/edm/.claude-plugin/plugin.json > /dev/null
jq -e . .claude-plugin/marketplace.json > /dev/null
```

### Ledger integrity (this round's own output)

```bash
LEDGER=SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
# every line is valid JSON, one finding per line
jq -e . "$LEDGER" > /dev/null && echo "ledger parses"
# expected counts for round 11
wc -l < "$LEDGER"                                        # 562
jq -s '[.[] | select(.status=="open")] | length' "$LEDGER"    # 42
jq -s '[.[] | select(.status=="noted")] | length' "$LEDGER"   # 69
jq -s '[.[] | select(.status=="fixed")] | length' "$LEDGER"   # 451
jq -s '[.[] | select(.resolved_round==11)] | length' "$LEDGER" # 45
jq -s '[.[] | select(.raised_round==11)] | length' "$LEDGER"   # 26
# the blocking set
jq -s -r '.[] | select(.status=="open" and (.sev=="P0" or .sev=="P1")) | .id' "$LEDGER"
# expected: CA-515, CA-536
# no duplicate IDs
jq -s -r '[.[].id] | length as $n | (unique | length) as $u | "ids=\($n) unique=\($u)"' "$LEDGER"
```

### Suites

```bash
bash plugins/edm/bin/tests/run-all.sh            # full local suite
bash plugins/edm/bin/tests/wave6-smoke.sh        # G1 (fixture), G20, G41, G42-adjacent
bash plugins/edm/bin/tests/wave7-smoke.sh        # G1, G3, G4, G9, G28-G40
bash plugins/edm/bin/tests/harness-smoke.sh      # G42
```

**Note (CA-130 / CA-331 / CA-377, outstanding for a seventh round)**: no lens had `Bash` this round,
so **the suite was not executed by any lens** and every FIXED verdict in this plan is read-derived.
A Bash-capable pass **must** run `bash plugins/edm/bin/tests/run-all.sh` immediately before the
convergence gate. Treat a green claim in this document as "green by inspection" until it does.

### Targeted per-finding checks

```bash
# G1 / CA-515 -- no ordinal-only spec survives anywhere
grep -rn 'qc-shard-pass-{NN}' plugins/edm/ ; # must return nothing
grep -rn 'qc-shard-pass-01\.md' plugins/edm/ ; # must return nothing

# G2 / CA-536 -- the amended AC13 Verify must now succeed
plugins/edm/bin/edm-state --help | grep -n 'spec_swept\|sweep-debt'

# G3+G4 / CA-541, CA-544 -- one RETURN trap left, and it names EXIT
grep -rn "trap .* RETURN" plugins/edm/bin plugins/edm/evals plugins/edm/bin/tests

# G5 / CA-537 -- the partial-run exit code is pinned somewhere
grep -rn 'RUN_EVAL_EC' .gitlab-ci.yml plugins/edm/bin/tests/

# G26 / CA-538 -- one printf, one-armed if
sed -n '140,155p' plugins/edm/bin/tests/run-all.sh
```

### CI

```bash
# lint + validate stages are scoped to plugins/edm/** and run on every MR touching the plugin
#   lint:shellcheck, lint:bash-syntax, lint:hooks-shell, lint:artifacts, lint:file-type-ban
#   test:smoke, test:smoke-bash32, test:state-validate
#   validate:manifest
# G14/CA-552 changes eval:nightly's artifacts block -- confirm the job still uploads run.json and
# scores.json, which the comparison step consumes.
```

### Rendered ledger

`findings-ledger.md` is the **rendered** view; `findings-ledger.jsonl` is authoritative and has been
updated. Regenerate the markdown before committing:

```bash
plugins/edm/bin/edm-state render-ledger EDMV3
```

This synthesizer had no `Bash` tool (CA-130), so the render was **not** run -- the `.md` is currently
stale relative to the `.jsonl` and must be regenerated by the orchestrator or the next
Bash-capable pass.

### Re-audit (targeted) after Wave 1

Re-run only the lens agents whose lenses own the fixed findings:

- **After Wave 1 (P1s)**: **L10**, **L11** (both owners of CA-515, and both must confirm all six
  surfaces agree and that `wave7-smoke.sh:9388` no longer pins the stale form), **L9** (CA-536),
  and **L3** (so its CA-515 verdict is re-derived against the producing surface this time, with
  `agents/edm-qc-auditor.md` explicitly in scope).
- **After Wave 2**: **L3** + **L5** (CA-541, CA-544), **L2** (CA-537), **L10** (CA-556), **L7**
  (CA-549), **L9** (CA-553, CA-554, CA-555).
- **After Wave 3**: **L8** (CA-550, CA-551, CA-552), **L11** (CA-558-CA-561), **L6** (CA-547,
  CA-548), **L4** (CA-543), **L5** (CA-545, CA-546, CA-171), **L2** (CA-538, CA-539).

A partial re-audit **cannot** satisfy the convergence gate. Only a full 11-lens round with zero open
P0/P1 can.
