# Explorer 03: Resolver divergence, data-directory lifecycle, duplication (Epic 3)

Scope: CA-072, CA-100, CA-103, CA-105, CA-106, CA-109, CA-112, CA-121. All facts below are
established by reading the current code on this branch (`edm/edmv4-ecc-integration`), not by
inferring from finding text or from `CLAUDE.md`. Where `CLAUDE.md` is quoted, it is quoted as a
CLAIM to be checked against code, and the code citation is given alongside it.

Line numbers in the original REMEDIATION.md prescriptions are frequently stale against the current
tree (the code has moved since the 2026-09-04 audit). All line numbers below are from the current
tree unless marked "(REMEDIATION cites ...)".

## Decision A -- project-root resolvers (CA-109, CA-112)

**Three resolution sites found, not two, matching CA-109's count. All three read in full.**

| Site | File:line (current) | Logic | CA-500 cross-check? |
|---|---|---|---|
| `_resolve_permcheck_project_root()` | `bin/edm-state:1172-1199` | 1. `CLAUDE_PROJECT_DIR` if non-empty and `-d`. 2. If also a git toplevel exists, physically resolve both (`cd ... && pwd -P`) and accept `CLAUDE_PROJECT_DIR` only if it equals or is contained under the physical toplevel; on disagreement, use the toplevel and print a stderr diagnostic naming both paths. 3. If no git toplevel at all, accept `CLAUDE_PROJECT_DIR` as-is (no repository boundary to check against). 4. Else use git toplevel. 5. Else `.`. | **Yes** -- this is the only one of the three that does the physical-path containment check. |
| `resolve_project_root()` | `bin/edm-hookify:141-153` | 1. `CLAUDE_PROJECT_DIR` if non-empty and `-d` -- returned immediately, no further check. 2. Else git toplevel. 3. Else `.`. | **No.** `CLAUDE_PROJECT_DIR` is accepted on a bare directory test with no comparison to git toplevel at all. |
| `edm_project_key()` | `bin/_edm-datadir-lib.sh:172-184` | 1. `CLAUDE_PROJECT_DIR` if non-empty and `-d` (`dir="$CLAUDE_PROJECT_DIR"`, no separate branch). 2. Else git toplevel. 3. Else `pwd`. Then encodes the result (`/`->`-`, `.`->`-`) as a project key. | **No.** Same unchecked acceptance as `edm-hookify`; this one also has no toplevel-disagreement branch, since its output is a *key* rather than a *path used for further resolution*, but the underlying value it keys on is exactly as spoofable. |

**edm-hookify's own comment is confirmed false.** `bin/edm-hookify:25-27` reads: "resolved the
same way `check_permission_rules()` resolves it in `bin/edm-state` (CA-448 baseline): CLAUDE_PROJECT_DIR
when it names a directory, else `git rev-parse --show-toplevel`, else `.`." That is the CA-448
baseline (pre-CA-500) description, and it is missing the CA-500 physical-path cross-check
`_resolve_permcheck_project_root()` (`bin/edm-state`) actually carries today. `CLAUDE.md`'s own
"Rule directory and discovery" section (Hookify rule format canonical) repeats the same three-step,
no-cross-check description as edm-hookify's comment -- so the doc and the comment agree with each
other, and both disagree with what `bin/edm-state` actually does. This is a live claim-vs-code gap,
independently established by reading `bin/edm-hookify:25-27`.

**Is the difference behavioral or stylistic? Behavioral -- established, not assumed.**
`bin/tests/wave6-smoke.sh` has a live CA-500 test band (`ca500_repo`/`ca500_attacker`, read at
`wave6-smoke.sh:1670-1690+`) that sets up a real attacker-controlled directory disagreeing with the
git toplevel and asserts `edm-state`'s permission-rule scan does NOT follow it. No equivalent test
exists for `edm-hookify`'s rule-directory resolution or for `edm_project_key()`'s key derivation --
confirmed by grep: `CA-500` appears only in `bin/edm-state` and its own smoke band, nowhere in
`bin/edm-hookify` or `bin/_edm-datadir-lib.sh`. Concretely: `CLAUDE_PROJECT_DIR=/attacker/dir`
(a directory that exists but disagrees with the real git toplevel) will:
- make `edm-state`'s permission-rule scan use the real toplevel (protected, with a stderr warning),
- make `edm-hookify` read rule files from `/attacker/dir/.claude/edm-hookify/*.json` instead of the
  real project's rule directory (unprotected -- an attacker-supplied rule set governs blocking
  decisions for the real repository, exactly as CA-109's Problem statement says),
- make `edm_project_key()` (and therefore `edm_marker_path()`, and therefore the Phase-6 marker
  path `edm-gateguard` reads to decide whether to evaluate `file`-event rules at all) key off
  `/attacker/dir` instead of the real project.

This is a correctness bug in two of the three sites, not merely a style/duplication issue: the
three implementations produce **different answers under the same adversarial input**, and only one
of the three is covered by a regression test for that input.

### CA-112 -- active-initiatives derivations

**Two implementations confirmed, and they disagree on phase range, not just on style.**

- `edm-repo-readiness`'s `_rr_active_prefixes()` (`bin/edm-repo-readiness:173-179`): when no
  `<PREFIX>` argument is given, runs `"$EDM_STATE_BIN" list 2>/dev/null | awk '/phase=/{print $1}'`.
- `cmd_list()` in `bin/edm-state:2559-2599` (the `list` subcommand `_rr_active_prefixes` pipes
  through awk): for **every** state file found by `list_state_files()` (both flat and product-scoped
  layouts, `.archived/` excluded), it prints a `phase=%d ...` line **regardless of the phase
  value** -- there is no filter on `current_phase` at all in `cmd_list`. Confirmed at
  `bin/edm-state:2586,2592,2595`: `phase` is computed and printed unconditionally.
- `edm-stop-gate` instead calls `edm-state active-initiatives` (`bin/edm-stop-gate:150`), which
  dispatches to `cmd_active_initiatives()` (`bin/edm-state:4243-4259`). This function **does**
  filter: `if [[ "$phase" -ge 1 && "$phase" -le 6 ]]` (`bin/edm-state:4250`) -- only initiatives at
  phase 1 through 6 inclusive are printed.

**Established, not assumed: `cmd_list`'s awk-scraped output includes phase 0 and phase 7+
initiatives that `cmd_active_initiatives` excludes.** An initiative that has been `edm-init`'d but
never had Phase 1 started (`current_phase` 0 or absent, read as 0) has a state file and appears in
`cmd_list`'s output with `phase=0`, which the awk pattern `/phase=/` matches -- so
`edm-repo-readiness` would count it as "active" while `edm-stop-gate`'s `active-initiatives` would
not. Symmetrically, an initiative recorded at phase 7 or above (post-terminal-phase, not yet
archived/moved to `.archived/`) appears in `cmd_list` but is excluded by `cmd_active_initiatives`'s
`-le 6` bound. This is the exact "phases 0 and 7 are included by one and excluded by the other"
claim in the CA-112 Problem text, and it is now confirmed against the two functions' actual bodies
rather than assumed from the finding text.

**Grouping check for Decision A: holds, and is a correctness question, not only consolidation.**
CA-109 and CA-112 are indeed "the same class" in the sense both are "N hand-rolled resolvers should
have been M" -- but CA-109's resolvers differ in a *security-relevant* way (attacker-controlled
`CLAUDE_PROJECT_DIR` redirects rule discovery and the Phase-6 marker key) while CA-112's two
derivations differ in an *operational* way (a scorecard and a Stop gate disagree about what counts
as "active"). Both are real behavioral differences, established by reading the functions, not
stylistic-only. The open question for Gate 2+3 is not "are these the same bug" (they are not
byte-for-byte the same bug) but "is one shared, tested resolver the fix for both, or do they need
separate fixes because one is a security boundary and the other is a reporting-consistency issue."

## Decision C -- duplication with no owner (CA-072, CA-121)

### CA-072 -- ASCII sanitizer

**Literal string `LC_ALL=C tr -c '\011\012\015\040-\176' '?'` found in exactly THREE production
files, not five:**

| File:line | Context |
|---|---|
| `bin/edm-gateguard:213` | `reason="$(printf '%s' "$reason" \| LC_ALL=C tr -c '\011\012\015\040-\176' '?')"` |
| `bin/edm-hookify:226` | Inside a named function, `hookify_scrub()` (`bin/edm-hookify:225-227`), called from 6 sites within the same file (`:248,255,417,418,419,443,448`) -- single owner *within* the file. |
| `bin/edm-stop-gate:123` | `printf '%s\n' "$text" \| LC_ALL=C tr -c '\011\012\015\040-\176' '?' >&2` |

Two more occurrences exist in `bin/tests/wave8-smoke.sh` (`:8996`, `:9027`) but these are `sed`
mutation patterns (`s@| LC_ALL=C tr -c .*@| cat@`) used to disable the sanitizer for a negative
control -- they match the literal to *mutate* it, they are not a fourth/fifth copy of the sanitizer
itself.

**This is a discrepancy with the finding's own count.** REMEDIATION.md's CA-072 Problem text says
"hand-copied five times across `edm-gateguard:163`, `edm-hookify:262-264` and `edm-stop-gate:82`"
(three files named, but "five times" and non-matching current line numbers). Current-tree grep
finds the literal exactly three times in production code, once per file named. Either the "five"
count included the two wave8-smoke.sh mutation-pattern occurrences (which are not copies of the
sanitizer, just string-literal-dependent test tooling), or the count is stale from a since-refactored
version of `edm-hookify` that had two inline copies before `hookify_scrub()` was extracted. I could
not establish which -- see "Not established" below.

**Drift check: all three are byte-identical today.** No character-class differences found across
the three call sites; only the surrounding `printf`/redirection shape differs (as expected, since
each is invoked in a different context: gateguard sanitizes a denial reason for its `emit_decision`
consumer, hookify sanitizes rule-authored text before printing, stop-gate sanitizes an already-hookify-formatted
line before writing to stderr).

**`edm-bash-gate` confirmed to have no sanitizing emit point of its own.** `bin/edm-bash-gate:131,136`:
`HOOKIFY_OUT="$(printf '%s' "$BASH_PAYLOAD" | edm-hookify eval bash)"` then
`printf '%s\n' "$HOOKIFY_OUT" >&2` -- a bare re-emit with no local `tr` call. This matches
REMEDIATION's characterization exactly: safety here is transitive (hookify's own `hookify_scrub()`
already cleaned the text before printing it) and unasserted (no test in edm-bash-gate's own
coverage proves the transitive safety holds if hookify's emit path ever regresses).

### CA-121 -- hooks.json UserPromptExpansion blocks

Read `plugins/edm/hooks/hooks.json` in full (142 lines). Five `UserPromptExpansion` blocks exist,
one per skill token: `edm:srd` (`:14-26`), `edm:audit-srd` (`:27-39`), `edm:tickets` (`:40-52`),
`edm:audit-tickets` (`:53-65`), `edm:implement` (`:66-78`).

**Structure**: each block has a `"type": "command"` hook (one line, differing only in the literal
gate-token substituted into `edm-state gate-check "$prefix" <token>`) and a `"type": "prompt"` hook
carrying a long (~1650-character) advisory prompt.

**The four non-implement prompts (`srd`, `audit-srd`, `tickets`, `audit-tickets`) are
byte-identical to each other apart from: (a) the gate-check subcommand token substituted into step 3,
and (b) the literal token appearing once more in the sentence "This is the SAME single rule the
command hook applies."** Confirmed by direct read/comparison of all five prompt strings.

**The `edm:implement` prompt (`hooks.json:75`) has ALREADY DRIFTED, confirmed and characterized
precisely.** Its step-3 sentence reads:

> "Otherwise run `edm-state gate-check <PREFIX> implement` (resolves the correct gate number from
> the initiative's mode and skipped_phases -- never hardcode one here, **and also enforces Gate 3.5
> when compliance_enabled=true**). This is the SAME single rule the command hook applies; ..."

The other four end the same parenthetical at "never hardcode one here)" with no additional clause.
`edm:implement`'s copy has one extra clause the other four do not: "and also enforces Gate 3.5 when
compliance_enabled=true". This is the exact drift CA-121's Problem statement names ("the `implement`
copy has already diverged with an extra Gate 3.5 clause"), now confirmed against the literal text
rather than taken on the finding's word.

Whether this extra clause is *correct* (i.e., whether `edm-state gate-check <PREFIX> implement`
really does fold in Gate 3.5 enforcement) is a separate, unverified question -- I did not trace
`cmd_gate_check`'s Gate-3.5 handling in this pass; flagged under "Not established."

**Grouping check for Decision C: holds.** Both CA-072 and CA-121 are "the same shape of defect" --
a literal (a sanitizer expression; a ~1650-character advisory prompt) hand-copied across multiple
files/blocks with no single source of truth, one copy already silently diverging from its
siblings. The open question is the same for both: extract to a shared owner (a lib function; a
prompt-template file or generation step), given JSON has no include mechanism (as REMEDIATION's
CA-121 Fix section already notes) so `hooks.json`'s fix shape differs mechanically from CA-072's
(a bash function extraction) even though the underlying defect class is identical.

## CA-106 -- set -e posture across the four hook consumers

Confirmed by direct grep of each file's own `set -...` line:

| File:line | Posture |
|---|---|
| `bin/edm-gateguard:49` | `set -euo pipefail` -- the only one of the four with `-e` |
| `bin/edm-hookify:101` | `set -uo pipefail` |
| `bin/edm-stop-gate:62` | `set -uo pipefail` |
| `bin/edm-bash-gate:66` | `set -uo pipefail` |

**No comment explaining the split found at edm-gateguard's `set -euo pipefail` line.** Read
`bin/edm-gateguard:40-49` (the lines immediately preceding it, inside its own `EDM-HELP` block) --
they document the gate's exit-code contract (0/1/2, and the two deny-mode behaviors), not the
reason this file alone carries `-e`. This matches REMEDIATION's claim that the split is
"uncommented" -- confirmed against the actual file content, not assumed.

**What each posture means for a hook, established from CA-077's already-fixed defect as a worked
example (not inferred, since CA-077's fix is visible in the current tree: `bin/edm-gateguard`'s
CLAUDE.md-documented "no jq exit status escapes that 0/1/2 contract any more" passage, and the code
at gateguard's decision-producing captures now explicitly checks status rather than letting it
propagate):**
- `set -e` (gateguard): any unguarded command in the script that returns non-zero -- historically,
  an internal `jq` failure (exit 5) on the gated path -- ABORTS the whole hook with THAT status
  instead of the script's own documented 0/1/2 contract, and whatever diagnostic the aborting
  command would have printed can be lost if it was captured into a variable (`$(...)`) with stderr
  redirected. CA-077 is the recorded instance of exactly this in gateguard, since fixed by
  explicitly guarding those four `jq` captures rather than by removing `-e`.
- No `-e` (hookify, stop-gate, bash-gate): a failing command inside the script does NOT abort it;
  execution continues to the next statement using whatever (likely empty or stale) value the failed
  command produced. This trades "loud abort with the wrong exit code" for "silent continuation on
  bad data," which is the class of defect this initiative's own `set -e`/pipefail constraints
  (`CC1`-`CC3` in analysis.md) exist to catch when it shows up in the test suite, but for a
  *hook consumer itself* (not a test), the risk runs the other way: an unguarded failure with no
  `-e` can let the hook reach its normal exit path having silently computed a wrong decision
  (allow when it should warn, or vice versa) rather than aborting loudly.

The open question this hands to Gate 2+3 is exactly "which posture is right for a hook" as
CA-106's own Problem text frames it -- not resolved here, since it is a design choice: `-e`
converts an unexpected internal failure into a loud, wrong-exit-code abort (bad for a hook, since a
hook's exit code is load-bearing for allow/deny/block); no `-e` converts it into silent
continuation on bad data (also bad, but differently). CA-077 shows gateguard already had to work
around `-e`'s failure mode by hand-guarding every capture on its gated path -- meaning `-e` did not
save effort there, it just moved the guarding burden to every individual command substitution.

## Decision B -- data-directory lifecycle and scoping (CA-100, CA-103, CA-105)

### CA-103 -- harvested pattern delta: host-global, confirmed; growth measured live on this host

`cmd_update_patterns()` (`bin/edm-state:6345-6498`) resolves its write target
(`bin/edm-state:6383-6399`) as `${data_dir}/patterns/${audit_type}-audit.md` where `data_dir` comes
from `edm_data_dir()` and `audit_type` is one of exactly 5 enum values
(`PATTERN_AUDIT_TYPE_ENUM_LIST="srd ticket qc code test-coverage"`, `bin/edm-state:909`). **The
path is keyed ONLY by `audit_type`, never by project/prefix/initiative.** This confirms CA-103's
"host-global rather than project-scoped" claim directly against the resolution code, not from the
finding text. Every initiative on a host sharing one resolved `CLAUDE_PLUGIN_DATA`/
`XDG_DATA_HOME`/`~/.local/share/edm` writes into the SAME 5 files.

**No cap, rotation, or eviction found anywhere in `cmd_update_patterns` or its body
(`_cmd_update_patterns_body`, `bin/edm-state:6289-6343`).** Every call that finds novel findings
appends (`_cmd_update_patterns_body`'s insertion logic, driven by `pattern_insert_line_for`).
Grepped `bin/edm-gateguard`, `bin/edm-state` and `bin/_edm-datadir-lib.sh` for
`sweep|reap|prune|evict`: zero matches anywhere in the codebase.

**Live measurement on this host** (not a fixture -- this is the real
`~/.claude/plugins/data/copilot-studio-skills-for-copilot-studio/` directory, the exact
foreign-plugin path CA-134/CLAUDE.md names):
- `patterns/` holds 5 files: `srd-audit.md`, `ticket-audit.md`, `code-audit.md`, `qc-audit.md`,
  `harvest-provenance.json`.
- `patterns/code-audit.md` alone already carries **144** `### CA-NNN (...)` finding headers.
  `patterns/srd-audit.md` carries 5.
- Content in `code-audit.md` is traceable to smoke-test scratch runs (`source: ZCA8`,
  `audit-type: code`, stub placeholder prose "delimited stub text pending human curation") -- this
  is CA-102's finding (smoke tests calling `update-patterns` into the real host data dir) made
  visible as accumulated real bytes on disk, not merely a theoretical risk.
- This directory ALSO already carries a `.edm-owned` sentinel (`_edm_datadir_owned()`'s marker,
  `bin/_edm-datadir-lib.sh:110-136`), meaning EDM has since claimed it under the CA-134/D46 fix; the
  pollution predates the claim and the claim does not undo it (matching `CLAUDE.md`'s own stated
  residual: "a directory EDM has ALREADY polluted carries `patterns/`, so it keeps being accepted
  until a human deletes it").

### CA-105 -- run/ triple accumulation: confirmed, no sweep, and live evidence of the actual leak

`bin/edm-gateguard` writes two of the three per-project-key files: `GG_CHECKED_FILE`
(`${state_dir}/${key}.checked`) and `GG_DENIALS_FILE` (`${state_dir}/${key}.denials`),
constructed at `bin/edm-gateguard:269-270`. The third, `<key>.phase6`, is written by
`_edm_marker_write()` in `bin/edm-state:90-96` (via `edm_marker_path()` in
`bin/_edm-datadir-lib.sh:194-200`), called from `cmd_phase_start` (`bin/edm-state:2883`, when
`phase == 6`) and from `cmd_session_start`'s marker-reconciliation logic
(`bin/edm-state:4784`, the CA-075-related "recreate a marker for a genuinely active phase-6
initiative" path).

No sweep code exists (confirmed by the same `sweep|reap|prune|evict` grep above returning zero
hits across the whole `bin/` tree).

**Live measurement, same host directory:** `run/` currently holds **85** `*.phase6` marker files
and **zero** `.checked`/`.denials` files. Every `.phase6` filename matches the pattern
`-var-folders-...-T--edm-wave6-<RANDOM6>-t06-cwd-<RANDOM6>.phase6` -- i.e. each is keyed off a
`mktemp`-generated scratch `CLAUDE_PROJECT_DIR` from a smoke-test run, never a real project. This
is the "wave6-smoke.sh writes markers into the real host data directory... currently unguarded"
fact from analysis.md, now directly measured rather than assumed: **85 stale marker files**, zero
value, permanent (nothing ever removes them).

**Traced the actual write path.** `bin/tests/wave6-smoke.sh`'s T06 band (`:1559-1690+`, "permission
`ask`-rule detection") isolates `HOME` (`T06_HOME`, a fresh `mktemp -d`) and `CLAUDE_PROJECT_DIR`
(`T06_CWD`, a fresh `mktemp -d`, exported at `:1580`) but **does NOT isolate `CLAUDE_PLUGIN_DATA`**
-- grepped the whole file's T06 band and found no `CLAUDE_PLUGIN_DATA` assignment anywhere near it.
The band calls `"$EDM_STATE" session-start` twice (`wave6-smoke.sh:1661,1666`) to test the
`PERM_RULES_MISSING` anomaly. `cmd_session_start()` (`bin/edm-state:4702-...`) reconciles Phase-6
markers for every active initiative it finds and, at `bin/edm-state:4784`, calls
`_edm_marker_write()` for any initiative it finds genuinely at phase 6 -- writing into
`edm_data_dir()`'s resolution, which (since `CLAUDE_PLUGIN_DATA` was never overridden by this test)
resolves to whatever the REAL host's `CLAUDE_PLUGIN_DATA` happens to be at the time the suite runs
-- while the project KEY comes from the overridden scratch `CLAUDE_PROJECT_DIR` (`T06_CWD`), which
is exactly why the 85 marker filenames on disk carry the `t06-cwd-XXXXXX` scratch-path shape. **This
establishes the "ALSO" question directly: yes, this belongs to Decision B.** It is the same
data-directory-scoping problem (host-global writes with no per-run isolation and no cleanup), just
triggered by test code rather than by a real Phase 6 session, and any scoping/cap/sweep fix for
CA-100/103/105 should account for -- or the test suite should separately be fixed to isolate
`CLAUDE_PLUGIN_DATA` the same way it already isolates `HOME` and `CLAUDE_PROJECT_DIR`.

### CA-100 -- gitignore coverage

`bin/_edm-datadir-lib.sh:87` (docstring) documents that `${data}/patterns/` is created by "the
first writing consumer" alongside `run/`; no code in `_edm-datadir-lib.sh` or `edm-state` writes or
checks a `.gitignore` entry anywhere near the resolved data directory. `CLAUDE.md`'s own
"Hookify rule format" section states plainly that `${CLAUDE_PLUGIN_DATA}` is reserved for
"plugin-internal caches only" and is never inside the project's own `SRD/` tree by contract -- but
that is a claim about WHERE the directory should be, not a control that prevents
`CLAUDE_PLUGIN_DATA` (or `XDG_DATA_HOME`) from resolving to a path that happens to sit inside some
git working tree (the consuming project's own, or an unrelated one on the same host). No code
anywhere adds or checks a `.gitignore` entry for the resolved data directory's `patterns/` or `run/`
contents. This matches CA-100's Problem statement directly.

## Constraint carried into Decision B (from the coordinator, and independently re-confirmed by code read)

`_edm_datadir_owned()` (`bin/_edm-datadir-lib.sh:110-136`) is the CA-134/D46 ownership test. Its
C-4 backward-compatibility clause, read in full: a directory that already exists, has no
`.edm-owned` sentinel, but DOES carry a `run/` or `patterns/` subdirectory (`:127`,
`[[ -d "${p}/run" || -d "${p}/patterns" ]] && return 0`) is still treated as EDM-owned. The comment
at `:116-126` states explicitly this is deliberate: "a strict sentinel-only test would silently
abandon all of them" (every install predating the sentinel). **Any scoping/cap change to
CA-100/103/105 that changes what `patterns/` or `run/` look like (e.g., splitting `patterns/` into
per-project subdirectories, or renaming the sweep-eligible marker shape) must not break this
`_edm_datadir_owned()` sentinel-fallback test**, since a directory this test can no longer recognize
as EDM's own reverts to being treated as a foreign plugin's directory -- exactly the failure mode
the coordinator's message and analysis.md both name (58 failing assertions from a prior
sentinel-only attempt). I did not locate the specific 58-assertion test run/commit this refers to
in this pass; flagged under "Not established."

## Grouping check overall

The three-way split (A: CA-109/CA-112; B: CA-100/CA-103/CA-105; C: CA-072/CA-121) holds under
direct code reading. Each pair/triple shares a genuine common mechanism (project-root resolution;
data-directory writes under `edm_data_dir()`; a hand-copied literal with no shared owner) rather
than being grouped only by proximity in the file list. Decision A additionally surfaces a fact the
grouping description undersold: CA-109's divergence is a security-relevant correctness gap
(unchecked `CLAUDE_PROJECT_DIR` acceptance), not merely a style inconsistency, so it is not
interchangeable with CA-112's operational (reporting-consistency) divergence even though both are
"N resolvers should be 1."

## Not established

- **CA-072's "five copies" count could not be reconciled.** Current-tree grep finds exactly 3
  production-code copies of the literal sanitizer expression (one per file: edm-gateguard,
  edm-hookify, edm-stop-gate). I could not determine whether REMEDIATION's "five" count (i) was
  measured against an earlier version of `edm-hookify` that had 2 inline copies before
  `hookify_scrub()` was extracted, (ii) counted the two wave8-smoke.sh mutation-pattern sites as
  copies, or (iii) is simply wrong. This matters for Decision C's cost estimate (extracting 3 call
  sites into a shared lib function is a smaller change than 5).
- **Whether `edm-state gate-check <PREFIX> implement` genuinely does fold in Gate 3.5 enforcement**
  (the claim `hooks.json`'s implement-block prompt drift asserts). I did not trace
  `cmd_gate_check`'s Gate-3.5 branch in this pass to confirm the extra clause is factually correct
  as opposed to merely present-and-diverged. If it is correct, the "fix" for CA-121 needs to
  either (a) special-case the implement block's extra clause when generating/sharing the five
  prompts, or (b) add the same clause to the other four if Gate 3.5 enforcement is not actually
  implement-specific -- I could not determine which from this pass.
- **The specific 58-failing-assertion test run/commit for the sentinel-only CA-134 regression**
  the coordinator's message and analysis.md both cite. I confirmed the CURRENT code's C-4 fallback
  clause and its stated rationale (`bin/_edm-datadir-lib.sh:116-126`), but did not locate the
  historical test run, commit, or ticket that recorded the 58-assertion failure count itself.
  Treat that count as coordinator-supplied, not independently re-derived here.
- **CA-100's gitignore fix scope for the CONSUMING project** (as opposed to this marketplace repo,
  which CLAUDE.md's Hookify section already separately documents as out of scope for the sibling
  `.claude/edm-hookify/` gitignore question). I did not check whether any shipped template or
  `edm-init` scaffold offers a `.gitignore` entry for a project that adopts EDM and ends up with a
  `CLAUDE_PLUGIN_DATA` inside its own tree; established only that no code currently manages this.
- **A precise measurement of "the real one" pattern-delta growth RATE** (findings-per-audit-round,
  or growth over time) was not possible from a single point-in-time snapshot -- I can report the
  current size (144 findings in `code-audit.md`) but not a rate, since I have no earlier snapshot
  to diff against and the git history of this data directory (outside any repo) is not tracked.
- I did not re-verify CA-500's smoke-test band beyond confirming its existence and its subject
  (`edm-state`'s permission-rule scan); I did not execute it or read every assertion inside it.
