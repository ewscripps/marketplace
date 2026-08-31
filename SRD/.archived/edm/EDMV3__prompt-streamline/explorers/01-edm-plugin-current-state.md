# Explorer 01 -- EDM Plugin Current State (EDMV3 prompt-streamline)

**Scope**: `plugins/edm/` (EDM plugin v2.0.0) as it relates to three changes: (1) HITL-gating `code_audit_converged`, (2) a canonical Mermaid literal-semicolon rule, (3) the `edm-init` branch-snapshot ordering defect.
**Method**: read-only. No files modified.

## 0. Tech stack and conventions

| Aspect | Value |
|---|---|
| Plugin version | 2.0.0 (`plugins/edm/.claude-plugin/plugin.json:4`) |
| Implementation | Markdown prompts (skills + agents) plus 4 POSIX bash scripts in `bin/` |
| Build / CI | None. No test runner; 4 hand-rolled smoke scripts in `bin/tests/` |
| State store | `SRD/{PRODUCT}/{PREFIX}__{DESC}/.edm-state.json`, mutated only via `bin/edm-state` (36 subcommands, jq-based read-modify-write under an advisory lock) |
| Enforcement surfaces | `hooks/hooks.json`: `UserPromptExpansion` gate-check, `PreToolUse` git-commit lint, `SessionStart`/`Stop`/`PreCompact` checkpoints, `SubagentStop` QC autospawn |
| Canonical conventions doc | `plugins/edm/CLAUDE.md` (473 lines) |
| Bash constraint | bash 3.2 compatible (macOS); explicitly called out at `bin/edm-init:170` |

---

## 1. Change 1 -- `code_audit_converged` needs a human gate

### 1.1 What exists today

`code_audit_converged` is a boolean in `.edm-state.json`, initialized `false`, flipped to `true` by an **agent** with zero human involvement, and read only by `edm-state archive`.

| Role | Location | Detail |
|---|---|---|
| Initialized | `bin/edm-state:542` | `code_audit_converged: false` in the `cmd_init` jq literal |
| **Written (auto)** | `skills/code-audit/SKILL.md:57` | Step 10: on zero open P0/P1, `edm-state set <PREFIX> code_audit_converged true` |
| **Written (auto)** | `skills/orchestrator/SKILL.md:557-558` | Step 8 point 5: "When REMEDIATION.md shows no new P0/P1 findings, record convergence: `edm-state set {PREFIX} code_audit_converged true`" |
| **Enabler** | `bin/edm-state:479-484` | `cmd_set` allowlists `code_audit_converged` alongside `compliance_enabled` as a settable boolean. This is the actual hole -- any agent with `Bash(edm-state *)` can set it |
| Read (enforced) | `bin/edm-state:868-891` | `cmd_archive` reads it; `die` at 887-889 when `false` and `product_name` is non-empty |
| Read (checklist) | `skills/orchestrator/SKILL.md:580-581` | Step 9 completion checklist |
| Exemptions | `bin/edm-state:883-886`; `skills/orchestrator/SKILL.md:560` | `mode=prototype` warns and proceeds; missing field ("legacy") warns and proceeds |

That is the full set. A tree-wide grep for `code_audit_converged` returns exactly these 9 hits and no others.

### 1.2 The ordering problem inside the code-audit skill

`skills/code-audit/SKILL.md` already has a human gate, but it fires **after** convergence is recorded and it is not machine-enforced:

- Step 10 (lines 54-67): convergence check -> sets the flag -> writes a "Post-Remediation Closure" note.
- Step 11 (line 69): "Read `REMEDIATION.md`. Present the HITL gate (summary below) and STOP for approval."
- The gate itself (lines 193-200) is free prose: *"Ask: 'Do you approve this audit plan and want me to remediate...'"*. It uses no `AskUserQuestion`, records nothing in state, and semantically gates **remediation**, not **convergence**.

So the sign-off that exists is the wrong gate, at the wrong point in the sequence.

### 1.3 This contradicts the plugin's own stated rule

`skills/orchestrator/SKILL.md:640-641` lists "**Auto-approve HITL gates**" as an anti-pattern, and line 645 states: *"Never auto-approve a HITL gate. Never skip a phase. Always record state via `edm-state`."* The current convergence flow violates this rule in the plugin's own orchestrator.

### 1.4 The Gate 3.5 pattern to mirror

Three coordinated pieces make Gate 3.5 work. All three have a direct analogue for a convergence gate.

**(a) State mutation -- `cmd_approve_gate`, `bin/edm-state:590-609`.** The special case is lines 597-602:

```bash
if [[ "$gate" == "3.5" ]]; then
  rmw_state "$prefix" '.compliance_gate_approved = true | .last_updated = $t' --arg t "$(now_utc)"
  echo "approved compliance gate 3.5 for $prefix at $(now_utc)"
  write_handoff_internal "$prefix"
  return 0
fi
```

The comment at 595-596 records the design rationale: a non-integer gate is stored as a dedicated boolean field rather than appended to `gates_approved`, "which expects integers -- avoids overloading numeric gate IDs." Note that the generic path (604-606) records `approved_at` and `approver` (`${USER}`, line 594); the 3.5 path records **neither**. A convergence gate arguably should capture both, which is a small divergence from the precedent worth deciding explicitly.

**(b) Deterministic enforcement -- `cmd_gate_check`, `bin/edm-state:1194-1237`.** Lines 1222-1234 add the conditional second check for `implement`. The convergence analogue is `cmd_archive:887-889`, which already exists -- so enforcement is the one piece that is largely in place, provided the field can no longer be set without approval.

**(c) Human prompt -- `skills/orchestrator/SKILL.md:267-285`.** The Gate 3.5 section: `AskUserQuestion` with header `"Gate 3.5"` (headers must be <= 12 chars), Approve / Revise / No-Go options, `edm-state approve-gate <PREFIX> 3.5` on explicit Approve only, then line 282: *"Apply the gate approval rules from Gate 1 -- free-text is never approval."* Those Gate 1 rules live at `skills/orchestrator/SKILL.md:395-402` and are the reusable contract (STOP and WAIT; only an exact "Approve" selection counts; re-present on free text; never infer intent from sentiment).

### 1.5 Ancillary code that a new gate touches

| Location | Why it matters |
|---|---|
| `bin/edm-state:474-496` (`cmd_set`) | `code_audit_converged` must be **removed** from the allowlist at line 479, or made to `die` with a redirect to `approve-gate`. Without this the gate is advisory only |
| `bin/edm-state:344-346` (`gated_phase_for_gate`) | Maps gate -> feeding phase for gate-review timing; returns `"null"` for unknown gates. A numeric convergence gate needs an entry (phase 6) |
| `bin/edm-state:1749-1779` (HANDOFF `next_action`) | Phase 6 currently emits one generic message (line 1777). A pending convergence gate should surface here |
| `bin/edm-state:1783-1788` (HANDOFF gate list) | Renders only `gates_approved`; like `compliance_gate_approved`, a dedicated boolean will not appear unless added |
| `bin/edm-state:1052-1068` (metrics gate-review timing) | Iterates numeric gates only |
| `bin/edm-state:419-467` (`state_anomalies`) | Candidate for a new anomaly: converged with no recorded approval |
| `bin/edm-state:1987`, `2017-2019` (dispatch + help) | Dispatch already routes `approve-gate`; the `--help` heredoc is `sed -n '2,39p' "$0"` over the header comment block (lines 2-39), so any new subcommand or gate must be documented there |
| `CLAUDE.md:404` | The `bin/` table hardcodes "36 subcommands" and enumerates them; needs updating if a subcommand is added |
| `CLAUDE.md:409-421` | The mode-family field table is where a new gate field would be documented |

### 1.6 Test surface

- `bin/tests/wave4a-smoke.sh:236-282` is a ready-made template: it asserts the pre-state is `false`, that `approve-gate 3.5` sets `compliance_gate_approved=true`, that `gates_approved` gains **no** decimal entry, and that `gate-check` flips from blocked to passing.
- `bin/tests/wave4b-smoke.sh:104-109` asserts the orchestrator SKILL.md **text** (section heading, `compliance_enabled=true` condition, `"Gate 3.5"` header string, the exact `approve-gate <PREFIX> 3.5` command). Prompt-text assertions are an established pattern here.
- **Gap**: grepping `bin/tests/` for `archive` or `converged` returns **zero matches**. There is no existing coverage of `cmd_archive` or the convergence flag at all.

### 1.7 Design decision the planning author must resolve

Two viable shapes:

1. **Reuse the field.** `approve-gate <PREFIX> 6.5` (or `4`) sets `code_audit_converged=true`; remove it from `cmd_set`. Minimal diff; but conflates "machine found zero P0/P1" with "human signed off", and the field name then lies about its meaning.
2. **Split the signals.** Keep `code_audit_converged` as the machine-computed zero-open-P0/P1 signal (still auto-set), add `code_audit_gate_approved` as the human boolean, and require **both** in `cmd_archive`. Cleaner semantics, matches the `compliance_enabled` / `compliance_gate_approved` pairing already in the schema (`bin/edm-state:542-543` sit adjacent), and lets the gate prompt state the machine finding as evidence. Costs one extra field plus a backward-compat default.

Option 2 mirrors the existing precedent more faithfully. Either way `CLAUDE.md`'s C-4 rule ("all fields default safely so v1.x state files without them work unchanged", line 421) requires the new field to default in a way that does not brick in-flight initiatives -- and a decision on whether existing `code_audit_converged=true` initiatives are grandfathered.

---

## 2. Change 2 -- Mermaid literal-semicolon rule

### 2.1 Verification of the fix

Confirmed against Mermaid upstream docs (`mermaid.js.org/syntax/flowchart.html` and the source markdown at `mermaid-js/mermaid:packages/mermaid/src/docs/syntax/flowchart.md`), section "Entity codes to escape characters":

> It is possible to escape characters using the syntax exemplified here.
> ```
> flowchart LR
>     A["A double quote:#quot;"] --> B["A dec char:#9829;"]
> ```
> Numbers given are base 10, so `#` can be encoded as `#35;`. It is also supported to use HTML character names.

The escape token is `#` + decimal code + `;` with **no leading ampersand**. Semicolon is decimal 59, so `#59;` is correct. The same page confirms `;` is a statement separator (optional as a terminator since 0.2.16, but still a reserved separator token).

### 2.2 Current state: the rule does not exist anywhere

Tree-wide greps confirm:
- `#59`, `&#`, and `semicolon` -> **zero matches** anywhere in `plugins/edm/`.
- ` ```mermaid `, `graph TD/LR/TB/RL`, `flowchart`, `sequenceDiagram`, `classDiagram`, `stateDiagram`, `erDiagram`, `gantt` -> **zero matches**. The plugin never ships a literal example diagram; it only instructs agents to author them. So there is no existing sample to fix, and every fix is a prompt-text addition.

The closest existing guidance is `agents/edm-architect.md:85-86`, which carves Mermaid out of the ASCII-only prose rule but says nothing about reserved characters:

> Keep all prose markers ASCII-only (no Unicode arrows or glyphs in text). Mermaid fenced blocks are permitted -- the ASCII constraint applies to prose, not to standard Mermaid syntax keywords.

### 2.3 Complete Mermaid touch-point inventory

**Authoring agents (3)**

| File | Lines | Content |
|---|---|---|
| `agents/edm-architect.md` | 4 | Frontmatter description: "Mermaid diagrams (system context + sequence)" |
| | 26-30 | Deliverable 3 "**Mermaid Diagrams** (mandatory)"; line 30 "Validate syntax -- diagrams must render without errors" |
| | 44 | Standards: "Diagrams must be syntactically valid Mermaid -- test edge cases" |
| | 67 | `architecture.md` output template: `[Mermaid system-context and sequence diagrams -- ASCII prose only, standard Mermaid syntax]` |
| | 85-86 | The existing ASCII/Mermaid carve-out -- natural anchor for a back-reference |
| `agents/edm-srd-writer.md` | 34 | Quality standard 3 "**Illustrated**" |
| | 58 | SRD template `## 5. Target Architecture (Mermaid diagrams required)` |
| | 79 | Process step 4 "Verify every diagram renders (check Mermaid syntax)" |
| `agents/edm-ticket-writer.md` | 5 | Frontmatter description: "critical path Mermaid" |
| | 39 | README requirement 5 "**Critical Path** -- Mermaid diagram, every node colored" |
| | 99 | Process step 8 "Draw the critical path Mermaid diagram with colored nodes" |

**Auditing agents (2)**

| File | Lines | Content |
|---|---|---|
| `agents/edm-srd-auditor.md` | 4 | Frontmatter lists the 7 categories including "Diagram Errors" |
| | **33-36** | `### 3. Diagram Errors` -- line 34 "Mermaid/PlantUML syntax errors (test every diagram)" |
| `agents/edm-ticket-auditor.md` | 40-44 | `### 4. Critical Path` -- line 41 "Mermaid diagram is syntactically valid?" |
| | **52-56** | `### 6. Diagram Correctness` -- line 53 "Mermaid syntax valid throughout?" |
| | 126 | Process step 4 "Check every Mermaid block for syntax" |

**Skills -- authoring (2)**

| File | Lines | Content |
|---|---|---|
| `skills/srd/SKILL.md` | 57 | Quality standard 3 "Illustrated" |
| | 82 | SRD template `## 5. Target Architecture (Mermaid diagrams)` |
| | 153 | `edm-architect` spawn prompt: "Include Mermaid diagrams (system context + sequence)..." |
| `skills/tickets/SKILL.md` | 43 | README requirement 5 "Critical Path -- Mermaid diagram, every node colored" |

**Skills -- auditing (2)**

| File | Lines | Content |
|---|---|---|
| `skills/audit-srd/SKILL.md` | 48-49 | `### 3. Diagram Errors` -- "Mermaid syntax errors, logical flow errors, missing edges, orphan nodes." |
| `skills/audit-tickets/SKILL.md` | 61-64 | `### 4. Critical Path` -- line 62 "Mermaid diagram syntactically valid?" |
| | 72-75 | `### 6. Diagram Correctness` -- line 73 "All Mermaid blocks valid?" |

**Pattern library (2)** -- these are the writer-agent inputs loaded at write time

| File | Lines | Content |
|---|---|---|
| `docs/audit-patterns/srd-audit.md` | 17 | Top-findings table row 4 "Diagram inconsistencies with prose, 9/16, P1" |
| | 38-42 | `### 4. Diagram inconsistencies with prose (9/16)` -- line 40 "Mermaid graph omits error-handling edges" |
| | 91 | Pre-Flight Checklist: "**Diagram walkthrough:** Step through each Mermaid sequence diagram vs. the corresponding prose..." |
| | 105, 108 | "What a Passing First Draft Looks Like" diagram bullets |
| `docs/audit-patterns/ticket-audit.md` | 33-36 | `### 3. Dependency DAG errors (7/16)` -- line 36 "`Depends On` edge declared but not drawn in the critical-path Mermaid" |
| | 86 | Pre-Flight Checklist: "**DAG verified:** ... confirm the corresponding edge is drawn in the critical-path Mermaid..." |
| | 98 | "What a Passing First Draft Looks Like" DAG bullet |

**Note on where the writers load these**: `agents/edm-srd-writer.md:25-28` and `agents/edm-ticket-writer.md:~28-31` instruct the agent to load the pattern doc at write time and treat `## Top Recurring Findings` / `## Anti-Patterns` as pre-emption guidance and `## What a Passing First Draft Looks Like` as the quality bar. That is the mechanism by which a pattern-library edit reaches the writers without editing the agent prompts -- confirmed by `docs/audit-patterns/README.md:34-44`.

### 2.4 Constraint: the pattern-library "Living-Library Contract"

`docs/audit-patterns/README.md:5-20` mandates that **each doc contains exactly four `##` headings, in this order**: Top Recurring Findings, Anti-Patterns, Pre-Flight Checklist, What a Passing [X] Looks Like -- with a documented regression guard that greps `^## `. Therefore:

- A Mermaid semicolon rule must be added as a `###` entry under **Anti-Patterns** and/or a bullet in **Pre-Flight Checklist**. It must **not** introduce a new `##` section.
- `cmd_update_patterns` (`bin/edm-state:1576-1692`) auto-appends novel `###` headings extracted from audit reports, de-duplicating on the normalized (lowercased, whitespace-collapsed, trailing-parens-stripped) title (lines 1632-1666), and always appends at end-of-file with severity P2 (line 1671). Consequences: (a) a manually added `### `-titled Mermaid anti-pattern is de-dup-safe and will never be auto-duplicated; (b) auto-appends land at EOF, i.e. **after** the fourth section, which already technically strains the contract -- worth noting but out of scope.

### 2.5 Where the canonical rule belongs in `CLAUDE.md`

The precedent is explicit. `CLAUDE.md:176-191` is `## Severity vocabulary (canonical)`, opening with *"All EDM audit agents use the following four-level scale. No agent may define a divergent local scale."* Five consumers point back to it **by name** instead of restating it:

- `skills/code-audit/SKILL.md:146` -- ``Use the **canonical** severity scale from `CLAUDE.md Sec."Severity vocabulary"` ``
- `skills/audit-srd/SKILL.md:65`
- `agents/edm-srd-auditor.md:63`
- `agents/edm-ticket-auditor.md:73`
- (plus the synthesizer's back-compat mapping at `CLAUDE.md:187-190`)

**Recommendation**: add `## Mermaid diagram conventions (canonical)` immediately **after** the Severity vocabulary section (i.e. inserted at `CLAUDE.md:192`, before `## Model and effort assignments` at line 193). Both are cross-cutting artifact-content rules; grouping them keeps the "canonical" sections adjacent. Every author and auditor then references it as ``CLAUDE.md Sec."Mermaid diagram conventions"``, exactly matching the existing quoting style. `agents/edm-architect.md:85-86` should point at it rather than grow an inline explanation.

Content the section needs: the `;` reserved-separator problem, the `#59;` fix with no leading `&`, a correct/incorrect example pair, the note that quoting alone is not a reliable substitute across diagram types (see risk R2 below), and a pointer that `sequenceDiagram` message text after `:` is unquoted and therefore especially exposed.

### 2.6 Can `edm-lint-artifacts` gain a 4th class? Yes, with one structural caveat

**Current shape** (`bin/edm-lint-artifacts`, 207 lines): header comment enumerates the 3 classes at lines 7-11; `build_ignore_set` at 69-109; class 1 attribution at 135-161; class 2 unicode at 163-183; class 3 leaked-tool-tag at 185-198 (a clean 13-line template: build ignore set, grep, skip ignored lines, `report_violation`). Scans every `*.md` under the resolved initiative dir (lines 117-128), so `architecture.md`, `srd.md`, and `tickets/README.md` are all in scope. Wired to `git commit` via `hooks/hooks.json:80-90`, which resolves prefixes from staged `SRD/` paths and fails the commit on non-zero exit.

**The caveat**: `build_ignore_set` toggles fence state at line 83 (`^\`\`\``) and emits every in-fence line number as **ignored** (lines 94-97). Mermaid always lives inside a ` ```mermaid ` fence. So all three existing classes deliberately skip exactly the region a Mermaid class must inspect -- indeed the class-3 comment at line 188 says the pattern is scoped narrowly "to avoid false positives on legitimate HTML in code fences or Mermaid diagrams."

A 4th class therefore cannot reuse `build_ignore_set`. It needs an **inverse** helper -- something like `build_mermaid_line_set <file>` emitting only line numbers inside ` ```mermaid ` fences. That is a straightforward variant of the existing loop (the fence-toggle already exists; it just discards the info string, so the new helper must capture the language token from the opening delimiter). The `<!-- edm-lint-ignore -->` markers should still be honored on top of it.

**Detection rule** (deterministic, conservative): within a Mermaid fence, flag a `;` that occurs inside a label span -- `[...]`, `(...)`, `{...}`, `|...|`, or `"..."` -- or after the `:` in a `sequenceDiagram` message. Required negative guards to keep false positives at zero:

- Do not flag `#<digits>;` or `#<name>;` -- these are the correct escapes, including the `#59;` fix itself and `#quot;`, `#35;`.
- Do not flag a trailing statement-terminating `;` at end of line (legal Mermaid).
- Do not flag `;` on `%%` comment lines.
- Do not flag `classDef` / `style` / `linkStyle` directive lines, which legitimately terminate with `;`.

**Verdict**: reasonable and worth doing. It is the only mechanism in the whole change set that gives a hard guarantee -- the other 11 touch points are prompt text, which is probabilistic. The trade-off is that it fires at commit time rather than authoring time, so it complements rather than replaces the prompt rule. Effort is one new helper plus one ~15-line scan block plus header-comment and `CLAUDE.md:407` table updates.

---

## 3. Change 3 -- `edm-init` branch-snapshot ordering

### 3.1 Code-level confirmation: the defect is real

Reading `bin/edm-init` end to end, the execution order is:

| Line(s) | Action |
|---|---|
| 20-28 | Flag parse; `DESCRIPTION` captured |
| 30-64 | Validate prefix, mode-family, slugs; global-uniqueness check |
| 69-97 | Resolve `DIR`; export `EDM_PRODUCT` / `EDM_DESCRIPTION` (74-75, 85-86); interactive description prompt at 78-89 |
| 99-101 | Abort if `DIR` exists |
| 104-133 | `mkdir -p "$DIR"`; scaffold `explorers/`, `decisions.md`, mode-dependent `code-audit/` |
| 135-138 | Export `EDM_MODE`, `EDM_COMPLIANCE_ENABLED`, `EDM_IMPLEMENTATION_MODE` |
| **139** | **`edm-state init "$PREFIX" >/dev/null`** |
| 141-146 | Optional `.gitignore` for `commit_state_file=false` |
| **148-168** | **Branch block**: 152 worktree check; 153-158 compute `BRANCH` (`edm/{prefix-lc}-{description}` or `edm/{prefix-lc}`); 159 `git rev-parse --verify "$BRANCH"`; 160 `git checkout "$BRANCH"` if it exists; **164 `git checkout -b "$BRANCH"`** if it does not |
| 170-187 | Print summary |

Inside `edm-state init` (`bin/edm-state:498-560`), line **510** runs `branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"` and line **535** writes it as `initiative_branch: $b`.

`git rev-parse --abbrev-ref HEAD` at line 510 therefore executes at `edm-init:139`, which is **25 lines and one atomic state-file write before** the `git checkout -b` at `edm-init:164`. On the intended path -- a fresh initiative whose branch does not yet exist -- `initiative_branch` is recorded as the **pre-init** branch (typically `main`).

### 3.2 Downstream blast radius

`cmd_branch_check` (`bin/edm-state:1264-1286`) reads `initiative_branch` (1270), compares to live `HEAD` (1275), and returns 1 with a `git checkout` advisory on mismatch (1280-1283). Because `edm-init` leaves the user standing on the **new** branch while state records the **old** one, the very next comparison mismatches.

The orchestrator treats this as a hard stop -- `skills/orchestrator/SKILL.md:296-298`, Step 1d:

> **Branch match** -- `edm-state branch-check <PREFIX>`. If it exits non-zero ... **BLOCK** and surface the `git checkout` instruction it prints; do not proceed with the phase until the branch matches.

So a freshly scaffolded initiative is blocked at Step 1d before Phase 1 begins, and the printed remedy (`git checkout main`) is actively wrong -- following it moves the user off the initiative branch. The only legacy escape hatch is an empty `initiative_branch` (line 1271), which a fresh init never produces.

### 3.3 Empirical check on EDMV3 -- did NOT reproduce, and here is why

I attempted to confirm the defect against the artifacts of the actual `edm-init --product edm --description prompt-streamline EDMV3` run. The on-disk evidence does **not** show the symptom:

| Evidence | Value |
|---|---|
| `SRD/edm/EDMV3__prompt-streamline/.edm-state.json:9` | `"initiative_branch": "edm/edmv3-prompt-streamline"` (correct) |
| `SRD/edm/EDMV3__prompt-streamline/.edm-state.json.bak:9` | Same correct value, with `current_phase: 0`, `phase_durations: {}`, `last_updated: 2026-07-25T03:22:27Z` |
| `.git/HEAD` | `ref: refs/heads/edm/edmv3-prompt-streamline` |
| `.git/logs/refs/heads/edm/edmv3-prompt-streamline` | Exactly one entry: `branch: Created from HEAD` at epoch **1784949700 = 2026-07-25T03:21:40Z** |
| `.git/logs/HEAD` | Exactly one matching entry: `checkout: moving from main to edm/edmv3-prompt-streamline`, same timestamp |

The branch was created at **03:21:40Z**; the surviving `edm-state init` wrote at **03:22:27Z** -- **47 seconds later**. A single `edm-init` invocation cannot produce that ordering, because line 139 always precedes line 164. So the state file on disk was written by an `edm-init` run (or repair) that happened **after** the branch already existed, which routes through the `git checkout "$BRANCH"` path at line 160. Checking out the branch you are already on is a git no-op that writes no reflog entry, which is consistent with seeing only one reflog record.

Note for the record (main-thread addendum): the actual cause on this run was that the orchestrating agent manually corrected `initiative_branch` via `edm-state set` after observing the branch-check failure, then re-ran `edm-init`-adjacent commands were not repeated -- so the "no reflog entry" reasoning above is consistent with a manual `edm-state set` correction rather than a second `edm-init` run. Either way the underlying ordering defect in `bin/edm-init:139` vs `148-168` is confirmed by static code reading, independent of this particular run's artifacts.

**Conclusion**: the defect is confirmed by code reading and is deterministic on the fresh-branch path (line 164). The repro condition for a regression test is precise: run `edm-init` from a branch where `edm/{prefix-lc}-{description}` does **not** yet exist.

### 3.4 Fix considerations

- Simply moving the branch block (148-168) above line 139 is the obvious fix, but note `edm-state init` needs its parent directory to exist -- it does its own `mkdir -p "$(dirname "$f")"` at `bin/edm-state:508`, so directory ordering is not a blocker.
- Failure semantics need a decision: lines 161-166 currently degrade to a warning when checkout fails and leave the user on the old branch. If branch creation moves first, `edm-state init` must record whatever branch actually resulted -- not the intended one -- otherwise the same mismatch reappears in the failure path.
- The alternative, lower-risk fix is to leave ordering alone and add a post-checkout correction after line 168: `edm-state set "$PREFIX" initiative_branch "$BRANCH"` guarded on successful checkout. This reuses the existing generic `cmd_set` string path (`bin/edm-state:491-494`), touches no ordering, and is naturally correct in the warn-and-continue paths.
- Either way `bin/edm-init` is bash-3.2 constrained (see the heredoc workaround comment at line 170).
- No test currently covers `edm-init` branch behavior.

---

## 4. Component inventory

| Component | Path | Status | Notes |
|---|---|---|---|
| Convergence auto-set (code-audit) | `plugins/edm/skills/code-audit/SKILL.md:54-68` | Modified | Step 10 must stop setting the flag; gate must move ahead of it |
| Code-audit HITL gate section | `plugins/edm/skills/code-audit/SKILL.md:193-200` | Modified | Prose-only, gates remediation not convergence; upgrade to `AskUserQuestion` + state record |
| Convergence auto-set (orchestrator) | `plugins/edm/skills/orchestrator/SKILL.md:550-560` | Modified | Step 8 point 5 replaced by a gate invocation |
| Step 9 completion checklist | `plugins/edm/skills/orchestrator/SKILL.md:569-581` | Modified | Add the new gate to the checklist |
| New convergence gate section | `plugins/edm/skills/orchestrator/SKILL.md` (new, near 267-285) | New | Mirror the Gate 3.5 section verbatim in structure |
| Gate 3.5 section (reference) | `plugins/edm/skills/orchestrator/SKILL.md:267-285` | Exists | Template. Do not modify |
| Gate 1 approval rules (reference) | `plugins/edm/skills/orchestrator/SKILL.md:395-402` | Exists | Reusable "free-text is never approval" contract |
| `cmd_approve_gate` | `plugins/edm/bin/edm-state:590-609` | Modified | Add a second special case beside the `3.5` branch at 597-602 |
| `cmd_set` boolean allowlist | `plugins/edm/bin/edm-state:474-496` (esp. 479) | Modified | Remove `code_audit_converged` or make it die with a redirect. **Load-bearing** |
| `cmd_init` state schema | `plugins/edm/bin/edm-state:498-560` (542-543) | Modified | Add the new gate field with a safe default |
| `cmd_archive` convergence check | `plugins/edm/bin/edm-state:860-903` (868-891) | Modified | Extend to require the human approval field |
| `cmd_gate_check` | `plugins/edm/bin/edm-state:1194-1237` | Exists | Enforcement precedent at 1222-1234; likely unchanged (archive is the enforcement point) |
| `gated_phase_for_gate` | `plugins/edm/bin/edm-state:344-346` | Modified | Add phase mapping if the gate is numeric |
| HANDOFF writer | `plugins/edm/bin/edm-state:1700-1975` (1749-1779, 1783-1788) | Modified | Surface a pending convergence gate in `next_action` and the gate list |
| `state_anomalies` | `plugins/edm/bin/edm-state:419-467` | Modified (optional) | Candidate anomaly: converged without approval |
| `edm-state` header/help | `plugins/edm/bin/edm-state:2-39`, `2017-2019` | Modified | `--help` prints lines 2-39 via `sed` |
| `cmd_init` branch snapshot | `plugins/edm/bin/edm-state:498-560` (510, 535) | Exists | Root of the ordering defect; may stay unchanged if `edm-init` is fixed |
| `edm-init` ordering | `plugins/edm/bin/edm-init:139` vs `148-168` | Modified | Reorder, or add a post-checkout `edm-state set` |
| `cmd_branch_check` | `plugins/edm/bin/edm-state:1264-1286` | Exists | Victim, not cause. No change needed |
| Step 1d branch enforcement | `plugins/edm/skills/orchestrator/SKILL.md:289-298` | Exists | BLOCK behavior makes the defect user-visible immediately |
| `edm-architect` | `plugins/edm/agents/edm-architect.md:26-30, 44, 67, 85-86` | Modified | Primary diagram author; add rule + back-reference at 85-86 |
| `edm-srd-writer` | `plugins/edm/agents/edm-srd-writer.md:34, 58, 79` | Modified | Add rule at process step 4 (line 79) |
| `edm-ticket-writer` | `plugins/edm/agents/edm-ticket-writer.md:5, 39, 99` | Modified | Add rule at process step 8 (line 99) |
| `edm-srd-auditor` cat 3 | `plugins/edm/agents/edm-srd-auditor.md:33-36` | Modified | Add literal-`;` as an explicit Diagram Errors check |
| `edm-ticket-auditor` dim 4 + 6 | `plugins/edm/agents/edm-ticket-auditor.md:40-44, 52-56, 126` | Modified | Add the check to dimension 6 and process step 4 |
| `skills/srd` | `plugins/edm/skills/srd/SKILL.md:57, 82, 153` | Modified | Line 153 architect spawn prompt is the highest-leverage spot |
| `skills/tickets` | `plugins/edm/skills/tickets/SKILL.md:43` | Modified | Critical-path diagram requirement |
| `skills/audit-srd` | `plugins/edm/skills/audit-srd/SKILL.md:48-49` | Modified | Category 3 mirror of the agent change |
| `skills/audit-tickets` | `plugins/edm/skills/audit-tickets/SKILL.md:61-64, 72-75` | Modified | Dimensions 4 and 6 |
| `docs/audit-patterns/srd-audit.md` | lines 38-42, 91 | Modified | Add under Anti-Patterns + Pre-Flight. Four-`##` contract applies |
| `docs/audit-patterns/ticket-audit.md` | lines 33-36, 86 | Modified | Same |
| `docs/audit-patterns/README.md` | lines 5-20 | Exists | Living-Library Contract; constrains where content may go |
| `cmd_update_patterns` | `plugins/edm/bin/edm-state:1576-1692` | Exists | De-dups by `###` title; manual additions are append-safe |
| `edm-lint-artifacts` | `plugins/edm/bin/edm-lint-artifacts:7-11, 69-109, 185-198` | Modified (proposed) | 4th class needs an inverse (mermaid-only) line-set helper |
| `hooks/hooks.json` git-commit hook | `plugins/edm/hooks/hooks.json:80-90` | Exists | Already invokes the linter; a new class needs no hook change |
| `CLAUDE.md` severity section | `plugins/edm/CLAUDE.md:176-191` | Exists | Naming/reference precedent |
| `CLAUDE.md` new Mermaid section | `plugins/edm/CLAUDE.md` (insert at 192) | New | `## Mermaid diagram conventions (canonical)` |
| `CLAUDE.md` bin table | `plugins/edm/CLAUDE.md:398-407` | Modified | Subcommand count/list and linter class description |
| `CLAUDE.md` state field table | `plugins/edm/CLAUDE.md:409-421` | Modified | Document the new gate field |
| `bin/tests/wave4a-smoke.sh` | lines 236-282 | Exists (template) | Bash-behavior test pattern for the new gate |
| `bin/tests/wave4b-smoke.sh` | lines 104-109 | Exists (template) | Prompt-text assertion pattern |
| New smoke tests | `plugins/edm/bin/tests/` (new file) | New | Zero existing coverage of `archive`, `code_audit_converged`, `edm-init` branch behavior, or the linter |
| `CHANGELOG.md` / `plugin.json` | `plugins/edm/CHANGELOG.md:7`, `.claude-plugin/plugin.json:4` | Modified | Version bump from 2.0.0 |
| `agents/edm-explorer.md` tool grant | `plugins/edm/agents/edm-explorer.md` (frontmatter `tools:`) | **New finding** | The explorer agent role has no `Write`/`Edit`/`NotebookEdit` tool, yet `skills/orchestrator/SKILL.md:305` and `skills/plan/SKILL.md` instruct "Each explorer writes its findings to `explorers/{NN}-{slug}.md`". Confirmed empirically: both EDMV3 explorer runs returned full report text and stated they could not write it. The orchestrating agent must write explorer reports on the explorer's behalf, or the agent needs a `Write` grant. |

---

## 5. Dependency map and ordering

- **Change 1 and Change 3 both edit `bin/edm-state` and `bin/edm-init`.** Serialize them or assign to one owner; both also touch `CLAUDE.md` and `CHANGELOG.md`.
- **Change 1 internal ordering**: schema field (`cmd_init`) -> `cmd_approve_gate` special case -> remove from `cmd_set` -> `cmd_archive` enforcement -> orchestrator gate section -> code-audit skill reorder -> HANDOFF surfacing -> tests. Removing from `cmd_set` before the gate exists would strand the flow, so the `approve-gate` path must land first or in the same commit.
- **Change 2 ordering**: the `CLAUDE.md` canonical section must land **first**; all 11 other touch points reference it by name and would otherwise dangle.
- **Change 2 linter is independent** of the prompt-text edits and can ship in parallel, but its violation class name should match the vocabulary chosen in the `CLAUDE.md` section.
- **No external service dependencies.** The optional Atlassian MCP (`skills/push-jira`) is untouched.
- **Shared infrastructure**: `hooks/hooks.json` (unchanged), the `PATH`-exposed `bin/` scripts, and `docs/audit-patterns/` (read at write time by two writer agents).
- **No blocking upstream work.** Change 3 is a prerequisite only in the practical sense that any fresh initiative used to exercise the other two will hit the Step 1d block until it is fixed. (Confirmed directly: EDMV3 itself hit this block and required a manual `edm-state set` correction to proceed.)
- **New finding (explorer write-access) is independent** and can be fixed alongside Change 3, or deferred -- it affects methodology ergonomics, not correctness of any artifact.

---

## 6. Constraints

| Constraint | Source | Impact |
|---|---|---|
| bash 3.2 (macOS) compatibility | `bin/edm-init:170`; `CLAUDE.md:429-430` | No associative arrays, no `{fd}` redirection, no `mapfile`. The linter's new helper must obey this |
| `gates_approved` holds integers only | `bin/edm-state:595-596`, asserted by `wave4a-smoke.sh:262-265` | A non-integer convergence gate must use a dedicated boolean field |
| C-4 backward compatibility | `CLAUDE.md:421` | New state fields must default so v1.x/v2.0 state files keep working |
| Legacy-initiative escape hatches | `bin/edm-state:885-886`, `1271-1274` | Absent fields must degrade to warn-and-proceed, not hard failure |
| Four-`##` living-library contract | `docs/audit-patterns/README.md:5-20` | Pattern-doc edits confined to existing sections |
| Artifacts are ASCII-only and linted at commit | `bin/edm-lint-artifacts:163-183`; `hooks/hooks.json:80-90` | All new artifact text must be ASCII; `#59;` is ASCII-safe |
| No AI-attribution trailers | `bin/edm-lint-artifacts:135-161`; root `CLAUDE.md` | Applies to commits and artifacts |
| Gitmoji shortcodes, never Unicode | root `CLAUDE.md` | Unicode breaks GitLab/Jira integrations |
| No `commands/` directory | `CLAUDE.md:8-12` | Skills only |
| Skills never load other skills | `CLAUDE.md:22-23` | Each skill carries its own orchestration; hence the duplicated convergence instruction in both orchestrator and code-audit skills |
| Plugin may be installed read-only | `bin/edm-state:1622-1625` | `update-patterns` already skips gracefully; anything writing into `docs/` must too |
| No CI | repo-level | Verification is `claude plugin validate` + `bin/tests/*.sh` run by hand (`CLAUDE.md:458-465`) |
| Explorer agents cannot write files | `agents/edm-explorer.md` frontmatter (no Write/Edit) | The orchestrating agent must persist explorer findings itself -- confirmed this run |

---

## 7. Complexity estimate

| Metric | Value |
|---|---|
| Files affected | ~20-22 distinct (Change 1: 7-9; Change 2: 14-16; Change 3: 2-3; overlap in `CLAUDE.md`, `CHANGELOG.md`, `bin/edm-state`, tests) |
| New modules | 0 new runtime modules. 1 new `CLAUDE.md` canonical section, 1 new orchestrator gate section, 1 new linter violation class + inverse fence helper, 1-2 new smoke-test files |
| Integration points | 8: `edm-state` dispatch/help, `cmd_archive` enforcement, `cmd_set` allowlist, HANDOFF writer, `hooks.json` commit lint, `update-patterns` dedup, pattern-library contract, `edm-init` -> `edm-state init` env/ordering handshake |
| Lines of bash changed | ~120-180 (mostly the linter's 4th class) |
| Lines of prompt text changed | ~150-250 across 13 markdown files |
| **Estimated ticket size** | **Small (10-20 tickets)** |

Rationale for Small: no application code, no data model, no external integrations, no migration. The work is concentrated, mechanical, and highly parallelizable -- the only genuinely novel engineering is the linter's inverse fence scanner. The main risk is breadth (13 markdown files must stay consistent), not depth.

---

## 8. Riskiest assumptions

| # | Assumption | Why it is risky | How to validate cheaply |
|---|---|---|---|
| R1 | `#59;` renders as a literal `;` in every Mermaid consumer the team actually uses | Verified only against upstream Mermaid docs. GitLab pins its own Mermaid version and sanitizes HTML in the markdown pipeline; GitHub, VS Code preview, and Mermaid Live all differ. If GitLab MR rendering emits a literal `#59;`, the rule makes diagrams worse, not better | Render one diagram containing `#59;` in a GitLab MR description, a GitHub `.md`, and VS Code preview before rolling the rule out. This is the single highest-value pre-flight check |
| R2 | `#59;` is the right fix rather than "quote the label" | Mermaid docs say quoting handles troublesome characters, which would be a simpler and far more readable rule. But `;` is a **lexer-level** separator, and `sequenceDiagram` message text after `:` is unquotable -- so the correct answer is plausibly diagram-type-dependent, and the rule may need two clauses rather than one | Test `A["a;b"]` in flowchart, `A-->|"a;b"|B` on an edge, and a `sequenceDiagram` message containing `;`. Record which forms parse |
| R3 | Prompt-level rules measurably change agent behavior | The failure is intermittent ("occasionally break"), so there is no reliable before/after signal. 11 of the 12 Mermaid touch points are prompt text with no verification mechanism | Treat the linter as the load-bearing control and the prompt edits as defense-in-depth. Assert the presence of the rule text in each file via a smoke test (the `wave4b-smoke.sh` pattern), which at least prevents silent regression of the guidance itself |
| R4 | The linter can detect in-label semicolons with zero false positives | Bracket/quote-span detection in POSIX grep is approximate. A false positive **blocks a commit**, so the failure mode is high-friction. `classDef`/`style`/`%%` lines and legal trailing terminators are all real counterexamples | Build a fixture corpus of ~15 diagrams (valid + invalid) and require zero false positives before wiring it into the commit hook. `<!-- edm-lint-ignore -->` already exists as an escape valve |
| R5 | Nothing external sets `code_audit_converged` via `edm-state set` | Grep across `plugins/edm/` finds only the two documented call sites, but user shell history, personal scripts, and other repos consuming this plugin are invisible | Make the removed `cmd_set` path `die` with an explicit "use `approve-gate` instead" message rather than silently falling through to the generic string branch (which would write the string `"true"` and quietly corrupt the boolean) |
| R6 | Existing initiatives with `code_audit_converged=true` should be grandfathered | Those flags were all set without human approval. If the new gate field defaults `false`, previously-archivable initiatives become un-archivable -- a backward-compat break against `CLAUDE.md:421` | Decide explicitly and encode it: either default the new field to mirror `code_audit_converged`, or add a `--force` / legacy-warn path matching the existing pattern at `bin/edm-state:885-886` |
| R7 | The `edm-init` fix is safe to apply by reordering | Moving `edm-state init` after the branch block changes failure semantics: the warn-and-continue paths at lines 161-166 leave the user on the **old** branch, so a naive reorder records the intended branch rather than the actual one and reproduces the same mismatch from the other direction | Prefer the post-checkout `edm-state set "$PREFIX" initiative_branch "$BRANCH"` correction guarded on checkout success, or capture the actual `HEAD` after the block. Add a regression test that runs `edm-init` from a branch where the target branch does **not** exist |
| R8 | The defect reproduces as described | Confirmed by code reading; not independently reproducible from the EDMV3 artifacts alone since a manual state correction intervened mid-run | The repro is precise and cheap: from a clean branch, run `edm-init --product X --description y ZZZ` where `edm/zzz-y` does not exist, then inspect `initiative_branch` before any manual correction |
| R9 | `bin/tests/` smoke scripts are actually run | There is no CI. `CLAUDE.md:458-465` describes manual verification only, and there is currently zero coverage of `archive`, `code_audit_converged`, or `edm-init` | Consider whether this initiative should add a single `bin/tests/run-all.sh` aggregator, so new tests are not written into a harness nobody executes |

---

### Files most worth reading first (for the planning author)

- `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md` -- lines 176-191 (severity precedent), 398-421 (bin table + state schema)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state` -- lines 474-496, 498-560, 590-609, 860-903, 1194-1237, 1264-1286
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-init` -- lines 139 and 148-168
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts` -- lines 69-109 and 185-198
- `/Users/darryl.porter/projects/marketplace/plugins/edm/skills/orchestrator/SKILL.md` -- lines 267-285, 289-298, 395-402, 550-581, 636-645
- `/Users/darryl.porter/projects/marketplace/plugins/edm/skills/code-audit/SKILL.md` -- lines 54-69 and 193-200
- `/Users/darryl.porter/projects/marketplace/plugins/edm/docs/audit-patterns/README.md` -- lines 5-20 (the four-heading contract)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave4a-smoke.sh` -- lines 236-282 (gate test template)

**Sources for the Mermaid verification:**
- [Mermaid flowchart syntax -- entity codes to escape characters](https://mermaid.js.org/syntax/flowchart.html)
- [mermaid-js/mermaid flowchart.md source](https://raw.githubusercontent.com/mermaid-js/mermaid/develop/packages/mermaid/src/docs/syntax/flowchart.md)
