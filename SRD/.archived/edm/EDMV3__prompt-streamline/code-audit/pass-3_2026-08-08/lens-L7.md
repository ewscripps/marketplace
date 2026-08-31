# Lens L7: Cross-File Consistency -- Pass 3 (2026-08-08)

## Method

Read the cross-round ledger in full; filtered to every open entry whose Lens(es) column includes L7 (CA-005, CA-010, CA-016, CA-019, CA-049, CA-074, CA-076, CA-079, CA-080, CA-081, CA-155, CA-156). For each, read the cited code and independently compared it against its sibling set. Then swept fresh for divergence introduced by the remediation itself: the 14 `bin/` entries, 3 `evals/` drivers, 8 `bin/tests/` suites, 30 `agents/*.md`, 14 `skills/*/SKILL.md`, `hooks/hooks.json`, `.gitlab-ci.yml`.

**Headline**: the Wave 6a extraction is real. `print_help` exists once (`bin/_edm-cli-lib.sh:28-30`), `report_violation` no longer guesses between counter names, `ignored_line_set` is no longer hand-copied, the FAF preamble and the N/A exit tokens are uniform across all 11 lenses and all 6 test writers, and `bin/` + `bin/tests/` are now zero-non-ASCII. Seven of twelve L7 entries are genuinely closed. The residue is a consistent shape: **the sweep patched every site the finding named and left the same defect standing in a sibling it did not name**, plus **two shared helpers that landed with zero callers**.

---

## Verdicts on L7-tagged open ledger entries

| ID | Verdict | Evidence |
|----|---------|----------|
| CA-005 | **Fixed in the main, 3 residual stragglers** (see F-2, F-3, F-4) | `bin/_edm-cli-lib.sh:28-30` is the only copy; CI ban landed at `.gitlab-ci.yml:112-125` (both the awk literal and the `sed -n 'A,Bp' "$0"` form); `edm-sync-canonical-sections:2-35` now has sentinels and `:36-38` records why. Compared all 13 callers. |
| CA-010 | **Fixed** | `wave7-smoke.sh:300-326` no longer greps `build_ignore_set`; the loop asserts each of the three consumers sources the library AND defines none of the three helpers locally; the label at `:301-302` now says "peer consumers of it, not of one another". |
| CA-016 | **Fixed (L7 half)** | `run-all.sh:59-70` asserts every `_PREFERRED_ORDER` name was discovered by name; `:71-75` adds `_MIN_SUITE_COUNT=7`. Deleting `wave7-smoke.sh` now exits 1 naming it. |
| CA-019 | **Fixed (L7 half), 1 sub-claim residual** | `evals/score-artifacts.sh:285` and `bin/_edm-lint-lib.sh:74` both do `awk -f "$MERMAID_RULES_AWK" -f <(...)` against the same `bin/edm-mermaid-rules.awk`; the 45-line clone is gone and the header at `:85-95` now states the opposite of the old "not attempted here" claim. Residual: the scorer still honours no `edm-lint-ignore` marker where `_edm-lint-lib.sh:146` does, and that asymmetry is stated nowhere -- defensible (a quality scorer should not let the artifact suppress its own measurement) but one sentence in the `:85-95` block would close it. |
| CA-049 | **Root derivation fixed in `bin/` + `evals/`; `bin/tests/` residual** (see F-5, F-6) | All 12 `bin/`+`evals/` scripts now use the identical `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"` one-liner under one name -- verified byte-identical at `edm-state:62`, `edm-lint-artifacts:60`, `edm-check-grants:64`, `edm-check-vocabulary:56`, `edm-check-skill-sync:30`, `edm-compare-eval:36`, `edm-init:19`, `edm-validate-prefix:18`, `edm-sync-canonical-sections:41`, `run-eval.sh:55`, `score-artifacts.sh:109`, `tiering-matrix.sh:67`. `SELF_DIR`/`PLUGIN_DIR` naming divergence is gone from `bin/`. The `_harness.sh` half did not land in practice. |
| CA-074 | **Fixed in part, 1 residual** (see F-1) | `edm-lint-artifacts:64-68` now defaults to `exit 2` in line with `edm-check-grants:72-76` and `edm-check-vocabulary:64-68`. `edm-validate-prefix:26-30` no longer sweeps the code into `$*` and carries its own in-place rationale at `:22-25`. All three `set -uo pipefail` sites now carry the comment the remediation asked for (`tiering-matrix.sh:62-64`, `score-artifacts.sh:101-106`, `run-eval.sh:47-52`), and `edm-compare-eval:31-33` / `edm-check-skill-sync:25-27` record their conversion to `-euo`. |
| CA-076 | **Fixed at the three named sites, 1 sibling straggler** (see F-7) | `lint:bash-syntax:126`, `lint:artifacts:142`, `lint:shellcheck:209` now each print `<job-name>: OK`, matching `lint:grants:156`, `lint:vocabulary:169`, `lint:pattern-library-contract:309`, `validate:manifest:535`, `validate:plugin-cli:570`. |
| CA-079 | **Fixed** | Ripgrep `[^\x00-\x7F]` over `plugins/edm/bin` returns exactly one hit: `bin/tests/fixtures/mermaid/valid/v12-indented-fence.md:9`, a fixture whose entire purpose is to carry an em dash inside an indented fence. `evals/`, `agents/`, `skills/`, `.gitlab-ci.yml` are all zero. `run-all.sh`'s printed strings (`:32`, `:68`, `:73`, `:77`, `:172`, `:178`, `:184`, `:187`, `:190`, `:193`) are ASCII `--` throughout. |
| CA-080 | **Fixed** | The FAF preamble sentence "Report every finding at your best-effort confidence level..." appears exactly once in each of all 11 lens files and nowhere else. `edm-audit-dead-code.md:48` and `edm-audit-logic.md:49` are byte-identical to `edm-audit-consistency.md:55`; the extra "Before reporting" preamble and the closing line are gone from both; each is followed by a bare 3-item numbered list with no trailing sentence. The severity clause is now the same bare sentence in all 11 (`logic:69`, `dead-code:68`, `dry:77`, `spec:84`, `docs:75`, `runtime:80`, `test-quality:73`, `edge-cases:75`, `consistency:75`, `security:81`, `wiring:90`) -- `logic`'s bulleted-field rendering is gone. |
| CA-081 | **Fixed on both named claims, 1 residual** (see F-10) | `edm-test-e2e.md:22`/`:139` is now `"N/A -- no e2e target"`; no token is a prefix of any other across the six (`no UI components`, `no hooks/composables`, `no API contract`, `no integration boundary`, `no HTML-rendering UI`, `no e2e target`). `a11y.md:136` now begins with its own Step-0 token, matching the `:138-139` claim. |
| CA-155 | **Fixed** | `_edm-lint-lib.sh:192-197` hard-fails (`return 1` + stderr diagnostic) when `violations` is undeclared instead of probing for a second spelling; `:60-67` documents the convention. All three consumers declare lowercase `violations` (`edm-check-grants:123`, `edm-lint-artifacts:142`, `edm-check-vocabulary:133`); grep confirms zero occurrences of `VIOLATIONS` anywhere in `bin/`. |
| CA-156 | **Fixed** | `edm-check-grants:125` and `edm-check-vocabulary:135` both carry `# ignored_line_set is provided by _edm-lint-lib.sh (CA-156) -- do not redefine it locally here.` and call it (`edm-check-grants:273`,`:295`; `edm-check-vocabulary:227`). The library exports all three projections at `:167-180`. `edm-lint-artifacts:294` parses the table itself, documented in place at `:284-291` as a deliberate one-scan-per-file optimisation -- one parser, justified. `edm-state:3938`,`:4001` is now a fourth consumer via the shared projection. |

---

## Findings (L7: Cross-File Consistency)

### F-1 (P2) -- `edm-sync-canonical-sections:47` is now the 4th `die()` shape and carries the exact defect CA-074 removed from its sibling

`plugins/edm/bin/edm-sync-canonical-sections:47`
```bash
die() { echo "edm-sync-canonical-sections: $*" >&2; exit "${2:-2}"; }
```
vs `plugins/edm/bin/edm-validate-prefix:26-30`, which the CA-074 remediation rewrote to
```bash
die() { local msg="$1" code="${2:-1}"; echo "edm-validate-prefix: $msg" >&2; exit "$code"; }
```
under a comment at `:22-25` explaining that the old `echo "...: $*"` form "printed the numeric exit-code argument as the last word of every message". `edm-sync-canonical-sections` is the one script in the family that reads `$2` as an exit code **and** interpolates `$*` as the message -- so the defect the remediation documented and removed is still live here in latent form. Currently harmless only because both call sites (`:56`, `:59`) pass a single argument; the next contributor who passes an explicit code gets it appended to the operator-facing text.

The family now has four shapes across eleven scripts:
- bare `$*` + hardcoded exit: `edm-state:71` (1), `edm-init:22` (1), `edm-check-skill-sync:33` (2), `edm-compare-eval:39` (2), `run-eval.sh:67` (2), `score-artifacts.sh:122-125` (2), `tiering-matrix.sh:72` (2)
- `local msg/code`, default 2: `edm-lint-artifacts:64-68`, `edm-check-grants:72-76`, `edm-check-vocabulary:64-68`
- `local msg/code`, default 1: `edm-validate-prefix:26-30` -- documented in place, see Noted
- `$*` message + `${2:-2}` code: `edm-sync-canonical-sections:47` **(this finding)**

**Fix**: give it the two-argument form its two siblings with a `${2:-}` exit code already use, and copy `edm-validate-prefix:22-25`'s comment.

### F-2 (P2) -- `edm-state:4599` is the only `print_help` caller that does not pass the argument the shared library documents

`plugins/edm/bin/edm-state:4599`
```bash
    print_help "$0"
```
Every other one of the 13 call sites passes `"${BASH_SOURCE[0]:-$0}"`: `edm-lint-artifacts:71`, `edm-check-grants:79`, `edm-check-vocabulary:71`, `edm-check-skill-sync:36`, `edm-compare-eval:42`, `edm-init:36`, `edm-validate-prefix:34`, `edm-sync-canonical-sections:53`, `run-eval.sh:70`, `score-artifacts.sh:128`, `tiering-matrix.sh:75`, `wave7-smoke.sh:756`. `_edm-cli-lib.sh:24-27` spells the convention out verbatim as the reason the function takes a path at all. `edm-state` is also the one script the suites `source` rather than execute (`wave7-smoke.sh:35`, `:4749`), which is exactly the case `$0` does not survive. Nothing asserts the argument shape -- `wave7-smoke.sh:4796-4802` checks only for form-B extractors, and `.gitlab-ci.yml:113` bans only a second copy of the awk literal.

**Fix**: one-character change to `print_help "${BASH_SOURCE[0]:-$0}"`, and extend the `wave7:4811-4815` per-file loop to assert the argument form, not just the `source` line.

### F-3 (P2) -- `edm-check-vocabulary` is the only member of the `print_help` family with two documentation blocks, and they have already drifted

`plugins/edm/bin/edm-check-vocabulary:2-53` is a 52-line header. `:74-82` is a separate, hand-maintained 8-line block -- the only one `--help` ever prints -- and it sits *below* the `die()`/`usage()` definitions and the `source` line, where all 12 siblings put a single sentinel-wrapped header at line 2 (`edm-check-grants:2-60`, `edm-init:2-15`, `edm-validate-prefix:2-14`, `edm-compare-eval:2-30`, `edm-check-skill-sync:2-23`, `edm-sync-canonical-sections:2-35`, `edm-state:10-54`, `edm-lint-artifacts:10-56`, `run-eval.sh:4-46`, `score-artifacts.sh:8-100`, `tiering-matrix.sh:2-60`).

The two blocks are already inconsistent with each other:
- `:47-48` (unreachable): `2 = usage or environment error (unknown flag, missing jq, unreadable scope path, invalid JSON)`; `:81` (printed): `2 usage or environment error` -- the enumeration is lost.
- `:13-16` (the eight scan roots), `:25-35` (the prohibited/allowlist data-file contract), `:37-39` (the one-grep-per-token performance contract) are all invisible to `--help`, where `edm-check-grants --help` prints its equivalent internals in full.
- `:5-8` and `:76-79` duplicate the Usage lines verbatim -- two sources of truth for one operator-facing string.

CA-005's whole premise was that `--help` must not silently omit documentation. The CI ban cannot catch this shape: it bans a duplicate *extractor*, not a duplicate *header*.

**Fix**: move `EDM-HELP-BEGIN` to `:1` and `EDM-HELP-END` to just above `set -euo pipefail`, delete the `:74-82` block.

### F-4 (P2) -- the three `evals/` drivers source the shared library by two different paths, and the smoke assertion was loosened to tolerate it

- `plugins/edm/evals/run-eval.sh:63`: `source "${EDM_BIN_DIR}/_edm-cli-lib.sh"` (via `:57-58`)
- `plugins/edm/evals/score-artifacts.sh:111`: `source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"`
- `plugins/edm/evals/tiering-matrix.sh:69`: `source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"`

All nine `bin/` helpers use one shape, `source "${SCRIPT_DIR}/_edm-cli-lib.sh"`. The test encodes the divergence rather than resolving it: `wave7-smoke.sh:4812` asserts the exact literal `source "\${SCRIPT_DIR}/_edm-cli-lib\.sh"` for `bin/` files, but `:4818` falls back to the bare substring `_edm-cli-lib\.sh"` for `evals/` files -- precisely because the two evals shapes differ.

**Fix**: settle on `"${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"` (2 of 3 already), then tighten `wave7:4818` to the same literal form `:4812` uses.

### F-5 (P2) -- `harness_scratch_dir()` and `_HARNESS_PLUGIN_DIR`/`_HARNESS_REPO_ROOT` landed for CA-049 with zero callers; the three suites they were written for still hand-roll the divergent preamble

`plugins/edm/bin/tests/_harness.sh:60-66` defines `harness_scratch_dir`, whose docstring at `:46-51` names its purpose exactly: *"CA-049: three older suites hand-rolled a byte-identical bare `mktemp -d` + `trap ... EXIT` preamble that did neither of those two things"*. Grep across the whole plugin returns **no call site**. The three suites are unchanged:

- `wave3-smoke.sh:15-16`, `wave4a-smoke.sh:15-16`, `wave5-smoke.sh:13-14`: `TMP="$(mktemp -d)"` + `trap 'rm -rf "$TMP"' EXIT` -- no `TMPDIR` honouring, no INT/TERM.
- `wave6-smoke.sh:19`/`:29` and `wave7-smoke.sh:22-23`: `mktemp -d "${TMPDIR:-/tmp}/edm-waveN.XXXXXX"` + `EXIT INT TERM`.

Same for the shared roots: `_harness.sh:41-44` adds `_HARNESS_PLUGIN_DIR` and `_HARNESS_REPO_ROOT` under the comment *"CA-049: shared plugin-root and repo-root exports so individual suites stop re-deriving the same value inline (five suites previously recomputed this...)"*. Both have **zero consumers**. All five still re-derive: `wave4b-smoke.sh:7`, `wave6-smoke.sh:10` and `:710`, `wave7-smoke.sh:12`, `timing.sh:26`, `harness-smoke.sh:8`. Only `_HARNESS_BIN_DIR` is used (`_harness.sh:104`, `wave6-smoke.sh:416`).

This is the sharpest instance of the pattern this round was asked to look for: the shared helper exists, is documented as the fix, and the divergence it was created to remove is untouched.

**Fix**: convert `wave3`/`wave4a`/`wave5` to `harness_scratch_dir TMP`, and replace the five inline root derivations with the `_HARNESS_*` exports -- or delete the unused exports and re-open the finding honestly.

### F-6 (P2) -- three residual root-derivation shapes inside `bin/tests/`, one of which contradicts `_harness.sh`'s own documented calling convention

Same sibling group, same class as F-5:

1. **`_harness.sh` sourcing, two shapes.** `_harness.sh:4` prescribes `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_harness.sh"`. Four suites follow it (`wave3:12`, `wave4a:12`, `wave5:10`, `wave6:16`) -- each recomputing a directory they already assigned to `SCRIPT_DIR` three lines earlier. Three do not (`wave4b:10`, `wave7:20`, `harness-smoke:11` all use `source "${SCRIPT_DIR}/_harness.sh"`). The three that deviate are the clean form; the docstring is what should change.
2. **`${BASH_SOURCE[0]}` vs `${BASH_SOURCE[0]:-$0}`.** Seven suites omit the fallback (`wave3:8`, `wave4a:8`, `wave5:6`, `wave6:8`, `timing.sh:25`, `harness-smoke.sh:7`, `run-all.sh:16`); two include it (`wave4b:6`, `wave7:10`). CA-049's remediation unified this across all of `bin/` and `evals/` and stopped at the `tests/` boundary.
3. **`timing.sh:26`** is a third shape for the same value: `PLUGIN_DIR="$(cd "${SCRIPT_DIR}/.." && cd .. && pwd)"` -- a two-step `cd` where `wave4b:7` and `wave7:12` use `"${SCRIPT_DIR}/../.."`. And `wave6-smoke.sh:710` declares `PLUGIN_DIR` 700 lines into the file where every sibling declares it in the preamble.

### F-7 (P2) -- `lint:file-type-ban` is now the only lint job without a job-named terminal verdict; `test:state-validate` drops its stage prefix too

CA-076's three named jobs were fixed, leaving the two siblings it did not name as the sole deviants.

`.gitlab-ci.yml:232`, `:253`, `:254` print `file-type-ban: clean -- ...`, `file-type-ban: tracked ... OK`, `file-type-ban: note -- ...` -- three lines, three shapes, none job-named, and no single terminal verdict. The failure branch at `:228` and `:247` likewise says `file-type-ban:` where `lint:pattern-library-contract:306` and `validate:manifest:532` say `<job-name>: FAILED`. `test:state-validate:423`/`:426` prints `state-validate: FAILED` / `state-validate: OK`.

Why it matters: the job-named verdict is the string an operator greps a 600-line pipeline log for. Seven of nine jobs print it; the two that don't are the ones whose names are hardest to guess from their output.

**Fix**: `lint:file-type-ban: OK -- no banned types, evals ${evals_kb}KB/100KB` as a single terminal line; `test:state-validate: OK`.

### F-8 (P2) -- `edm-test-integration` declares an N/A exit token that three enumerating sources say cannot exist

*Closest to P1 in this batch: the failure mode is a silently unmeasured test layer.*

`plugins/edm/agents/edm-test-integration.md:21-22` (Step 0), `:96-98` (Output) and `:104-107` (`## When this does NOT apply`) give integration a full self-N/A carve-out, in the same three-part shape as its five siblings. But:

- `plugins/edm/agents/edm-test-planner.md:78-82` -- the agent that **assigns** N/A -- lists exactly `component`, `a11y`, `composable`, `contract`, `e2e`. Integration is absent, so the planner can never mark it N/A.
- `plugins/edm/agents/edm-test-unit.md:100-102`: *"unit is never itself marked N/A by `edm-test-planner` (only `component`, `composable`, `contract`, `e2e`, and `a11y` can be -- see `agents/edm-test-planner.md`)"* -- an explicit five-member enumeration excluding integration.
- `plugins/edm/CLAUDE.md` "Layers that are N/A" enumerates the same five.

`edm-test-planner.md:73` does carry an `integration` row in the framework table whose Status column includes `N/A`, so the table permits what the rules never define. Consequence: `edm-test-integration` can self-report N/A on a layer the planner marked active, and `edm-test-coverage-auditor.md:84`/`:234`/`:267` then *"Skip N/A layers entirely"* and *"Don't flag N/A layers as gaps -- absence is authoritative"* -- so the layer disappears from `test-coverage.md` with no finding raised.

**Fix**: pick one. Either add `- \`integration\` is N/A unless the epic's Target Components cross a module or service boundary` to `edm-test-planner.md:78-82` and add integration to the two enumerations, or delete the carve-out from `edm-test-integration.md:21-22`, `:96-98`, `:104-107`.

### F-9 (P2) -- `hooks.json`'s `edm:audit-srd` hook passes a sibling's gate token, so the refusal message names the wrong command

`plugins/edm/hooks/hooks.json:32` (matcher `edm:audit-srd`):
```
edm-state gate-check "$prefix" srd
```
The other four UserPromptExpansion hooks each pass their own command name: `:45` `tickets`, `:58` `audit-tickets`, `:71` `implement` (and `:19` `srd` for matcher `edm:srd`). `bin/edm-state:2929` accepts `srd|audit-srd` as distinct tokens mapping to the same gate, and `:2901-2902` states the contract as *"all eight phase-skill tokens resolve"* -- so the `audit-srd` alias exists specifically so this caller can name itself, and is the one token no caller uses.

Live consequence at `bin/edm-state:2974`:
```bash
echo "Run /edm:orchestrator ${prefix} and approve Gate ${required_gate} before running /${gated_cmd}." >&2
```
A user blocked while invoking `/edm:audit-srd` is told *"before running /srd"* -- a command they did not run. The five hooks are otherwise byte-identical in shape, so nothing signals this as deliberate.

**Fix**: `edm-state gate-check "$prefix" audit-srd` at `hooks.json:32`. Behaviour-identical, message correct.

### F-10 (P2) -- CA-081 residual: two of six test writers insert extra words between the token and the parenthetical, under a line claiming the string is identical

`edm-test-component.md:103` -- `N/A -- no UI components in scope (backend-only, CLI, library without DOM rendering).`
`edm-test-composable.md:123` -- `N/A -- no hooks/composables in scope (no React hooks or Vue composables).`

against the four that render token-then-parenthetical directly: `contract.md:106`, `integration.md:106`, `a11y.md:136`, `e2e.md:147`. In all six the next line asserts *"This is the same exit token as Step 0's carve-out above, named here so the caller can rely on a uniform signal"* -- literally true for four, prefix-true for two. This is the same defect CA-081 raised against `a11y` and the remediation fixed there.

**Fix**: drop ` in scope` from `component.md:103` and `composable.md:123` (their Step-0 tokens at `:21` and `:20` don't contain it).

### F-11 (P2) -- `_edm-lint-lib.sh`'s header undercounts its consumers and names a variable no consumer uses

`plugins/edm/bin/_edm-lint-lib.sh:4-7`:
> *"Its three consumers are bin/edm-lint-artifacts, bin/edm-check-grants and bin/edm-check-vocabulary. All three source it by relative path from their own script directory (`source "${SELF_DIR}/_edm-lint-lib.sh"` or equivalent)"*

There are **four** consumers -- `bin/edm-state:64` was added by the CA-056 remediation and uses `ignored_line_set`/`is_ignored_line` at `:3938`, `:4001`, `:4007`. And `SELF_DIR` no longer exists anywhere in the tree: CA-049 unified every consumer onto `SCRIPT_DIR`. A contributor changing this API will consult this header, undercount the blast radius by one file, and grep for a variable name that returns nothing.

**Fix**: "four consumers", add `bin/edm-state`, change `SELF_DIR` to `SCRIPT_DIR`.

---

## Noted / Not Actionable

1. **`edm-validate-prefix:26-30` still defaults `die()` to exit 1 where 8 siblings default to 2** -- documented in place at `:22-25` ("Family contract: 1 = invalid format, 2 = collision") and in its own `--help` exit-code table at `:7-10`; all four call sites (`:39`, `:43`, `:53`, `:68`) pass an explicit code, so the default is never load-bearing. FAF #1+#2.
2. **`edm-state:71` and `edm-init:22` default `die()` to exit 1 where the six checkers default to 2** -- the checkers reserve exit 1 for "violations found" (`edm-lint-artifacts:40`, `edm-check-vocabulary:47`); `edm-state` and `edm-init` have no violation concept, so 1 is their generic error. Consistent within each sub-family. FAF #3.
3. **Test-writer `maxTurns` diverge (a11y 30, e2e 60, the other five 50)** -- every value is enumerated and matched in `plugins/edm/CLAUDE.md:513-524`'s "Testing layer agent inventory", with the colour rationale at `:526-528`. Documented as intentional. FAF #1.
4. **No UserPromptExpansion hook for `edm:code-audit` / `edm:verify-runtime` although `edm-state:2932` gates both on Gate 3** -- the hook set is enumerated exactly as shipped in `CLAUDE.md:649` (`edm:(srd|audit-srd|tickets|audit-tickets|implement)`), so producer and doc agree. FAF #1. Residual doc gap only: nothing states *why* two of the eight gated tokens get no deterministic hook.
5. **`evals/score-artifacts.sh:285` honours no `edm-lint-ignore` marker where `_edm-lint-lib.sh:146` does** -- defensible by construction (a quality scorer must not let the artifact under measurement suppress its own score) and the `:85-95` header already partitions what is shared from what is deliberately local. Recorded here rather than as a finding; one sentence in that block would settle it permanently.
6. **`edm-check-skill-sync:49-72` increments its own `violations` and prints its own format instead of using the shared `report_violation`** -- it reports duplicated-block pairs, not `file:line:class:snippet` violations, so neither the 4-arg nor the 5-arg shape fits. Different output contract, not a divergence. FAF #3.
7. **`edm-check-grants`/`edm-check-vocabulary` wrap `is_ignored_line` in a redundant `[[ -n $ignore_set ]]` guard where `edm-lint-artifacts` calls it bare** -- already accepted as CA-173 (cosmetic, no behavioural difference). Unchanged; do not re-raise.
8. **The 11 lens agents' frontmatter** -- verified byte-identical across all 11: same `tools:` line, `model: opus`, `effort: max`, `maxTurns: 30`, `color: cyan`, `disallowedTools: Edit, NotebookEdit`. Zero drift. Consistent-project-pattern.
9. **The five UserPromptExpansion `command` hooks** -- byte-identical in shape including the `*[!A-Za-z0-9_-]*` charset guard, differing only in the gate token (see F-9) and gate number. Consistent.
10. **The 14 `SKILL.md` frontmatter blocks** -- all carry `disable-model-invocation: true`, all `allowed-tools` grants are a subset of one vocabulary, and the artifact-writing phase skills now all hold `Edit` (CA-032 closed: `plan/SKILL.md:8` has it). Read-only skills (`metrics:8`) correctly omit `Write`/`Edit`. Consistent.

---

## Coverage / limits

Compared as sibling groups: the 14 `bin/` entries and 3 `evals/` drivers on shebang, `set` flags, root derivation, library sourcing, `die()`, `usage()`/`print_help`, help-sentinel placement and exit-code contracts; the 8 `bin/tests/` suites on preamble, scratch-tree hygiene, harness sourcing and summary shape; all 11 lens agents on frontmatter, FAF preamble, Output contract and severity clause; the 7 test-writer agents on N/A carve-out, Output bullet and "When this does NOT apply"; all 14 skills on frontmatter and grants; `hooks.json`'s five expansion hooks against each other and against `edm-state`'s gate-check token table; all 9 `.gitlab-ci.yml` blocking jobs on image/rules anchors, `needs:`, `before_script` pinning and terminal verdict shape.

Not compared: `bin/edm-state`'s ~4,600-line subcommand body internally (only its preamble, `die()`, `print_help` and `gate-check` were read); `monitors/monitors.json`; `docs/audit-patterns/*.md` beyond the enumerations F-8 depends on; individual assertion bodies inside `wave6`/`wave7` beyond the CA-cited blocks; the SRD and ticket pack (L9's scope).

**Blocking process note**: `Write` was absent from this lens's runtime tool set for the third consecutive round (CA-130). This report was returned as text for transcription to `SRD/edm/EDMV3__prompt-streamline/code-audit/pass-3_2026-08-08/lens-L7.md`; no `lens-L7.jsonl` could be emitted either, so the orchestrator must persist both halves. CA-176's recommendation -- an explicit orchestrator-persists-both-halves fallback in `skills/code-audit/SKILL.md` -- is now three rounds overdue.
