# Lens L6 -- Documentation Accuracy (round 8, full)

Scope swept: plugins/edm/bin/*, plugins/edm/bin/tests/*, plugins/edm/agents/*.md,
plugins/edm/skills/*/SKILL.md, plugins/edm/hooks/hooks.json, plugins/edm/monitors/monitors.json,
plugins/edm/evals/*.sh (+ evals README/baseline/fixture docs reached by cross-reference),
plugins/edm/CLAUDE.md, README.md, CHANGELOG.md, docs/*, and the repository-root .gitlab-ci.yml.

## Prior-round findings, re-verified against current code

- **CA-366 -- FIXED.** `bin/tests/wave7-smoke.sh:7942` now reads "all four per-class call sites
  (attribution, unicode on both platform branches, leaked-tool-tag)". The count is computed at
  :7940 (`count_matches '_lint_report_class_hits "'`), asserted `-eq 4` at :7941, and the
  follow-on comment at :7944-7947 restates the same enumeration ("all four call sites (including
  both unicode platform branches)"). Label and parenthetical now agree.
- **CA-406 -- FIXED, both sites.** `bin/edm-state:4534-4538` cites the site by name
  ("hooks.json's SubagentStop/edm-implementer prompt and skills/implement/SKILL.md's Step 5
  remediation step 2") and states the rationale explicitly: "CA-406: named by anchor, not line
  number -- an unrelated insertion above either site would silently falsify a bare ':117'
  citation with nothing failing." `bin/edm-check-grants:415-421` carries the reciprocal note.
  Neither file contains a `hooks.json:117` or `SKILL.md:117` citation any more. One residual
  side effect is reported as F6 below.
- **CA-407 -- PARTIALLY FIXED; re-flagged as F5.** The honesty caveat did land
  (`CLAUDE.md:883-886`), but the same paragraph names the wrong test suite and, in correcting
  the overclaim, introduced an underclaim.
- **CA-408 -- STILL OPEN; re-flagged as F8 with corrected file attribution.** The malformed
  banner is in `bin/tests/wave7-smoke.sh:223-225`, not `bin/edm-state`. `bin/edm-state` contains
  no `# ====` section banners at all (verified: zero matches for `^# =====` in that file), so the
  prior round's file attribution was wrong rather than the finding being resolved.

## Findings (L6: Documentation Accuracy)

### F1 [P1] plugins/edm/CLAUDE.md:1011-1036 -- CI job table omits the blocking `lint:hooks-shell` job, and both job-graph counts are stale

**Doc says.** The `lint` stage rows at :1013-1019 present a complete inventory of CI jobs (seven
lint rows). :1032: "the runner fleet executes all seven concurrently and each reports its own
pass/fail." :1036: "The pinned image and shared rule set live in one `.alpine_edm` anchor so a
digest refresh stays a single-line change across all ten consumers."

**Code does.** `.gitlab-ci.yml` defines EIGHT lint jobs: `lint:bash-syntax` (:85),
`lint:artifacts` (:154), `lint:grants` (:175), `lint:vocabulary` (:194), `lint:shellcheck`
(:227), **`lint:hooks-shell` (:275)**, `lint:file-type-ban` (:322),
`lint:pattern-library-contract` (:370). `lint:hooks-shell` is blocking (`needs: []`, no
`allow_failure`), was added by CA-380, and is the only job that lints the plugin's most
privileged shell -- every command-type hook string in `hooks/hooks.json`, run through `bash -n`
plus `shellcheck --shell=sh`. It has no row in this table at all. Separately, `<<: *alpine_edm`
has ELEVEN consumers (:87, :156, :177, :196, :229, :277, :324, :372, :425, :496, :545), not ten.

**Fix.** Add a `| lint | lint:hooks-shell (CA-380) | Yes | bash -n + shellcheck --shell=sh over
every command-type hook command string in hooks/hooks.json ... |` row. Change "all seven
concurrently" -> "all eight concurrently" and "all ten consumers" -> "all eleven consumers".
Durability: pin both numbers with computed assertions in the shape `wave7-smoke.sh:4296` already
uses -- compare `grep -c '^lint:' .gitlab-ci.yml` and `grep -c '<<: \*alpine_edm'
.gitlab-ci.yml` against the numbers this paragraph states, and assert one table row per `^lint:`
job (the shape `wave7-smoke.sh:1232-1245` already uses for the `bin/` table), so the next added
job fails a test instead of drifting.

### F2 [P2] .gitlab-ci.yml:56-58 and :78-82 -- the same two counts are stale in the pipeline file's own header comments, and one names the exact `grep -c` that now disagrees with it

**Doc says.** :56-58: "The pinned alpine image and the shared rule set are identical across every
lint job -- seven of them today -- plus three non-lint jobs that need only bash/jq/git on Alpine
(test:smoke, test:state-validate, validate:manifest); ten consumers total (`grep -c '<<:
\*alpine_edm'` over this file)." :78-82: "the lint stage has since grown three more the same way
(lint:shellcheck, lint:file-type-ban, lint:pattern-library-contract) -- seven lint jobs total
today ... the runner fleet executes all seven concurrently."

**Code does.** Eight lint jobs and eleven `<<: *alpine_edm` consumers, in this same file. The
comment cites a specific command whose output (11) contradicts the number it states (10), and
the "grown three more" list is missing the fourth one grown the same way, `lint:hooks-shell`.

**Fix.** "eight of them today"; add `lint:hooks-shell` to the parenthetical, making it "grown
four more"; "eleven consumers total". Same computed assertion as F1 covers both files at once.

### F3 [P1] plugins/edm/evals/baseline/README.md:94-104 -- the baseline runbook prescribes a JSON field name that `bin/edm-compare-eval` never reads

**Doc says.** :91-104, the instruction for arming the eval tripwire: "When the baseline is
captured, add a `variance` object to `baseline/scores.json` itself, e.g.

    "variance": {
      "total_max_minus_min": 0.0,
      "per_dimension_max_minus_min": { ... }
    }

**Code does.** `bin/edm-compare-eval:102` reads `jq -r '.variance.total_range // 0'`. The string
`total_max_minus_min` occurs nowhere else in the repository, and nothing anywhere consumes
`per_dimension_max_minus_min`. `edm-compare-eval`'s own help header (:14-16) and
`plugins/edm/CLAUDE.md:785` both name `variance.total_range`.

**Consequence (why P1, not P2).** An operator following this runbook exactly arms the tripwire
with the documented "A missing variance record is treated as 0 -- strict" fallback silently
engaged. Every subsequent run then compares against `threshold = baseline.total - 0`, so ordinary
run-to-run noise is reported as `REGRESSION` (exit 1) with a `variance allowed: 0` line on screen
that looks deliberate rather than like a misconfiguration. This is the one document that tells a
human how to arm the tripwire, and it costs three live eval runs to reach the point of finding
out.

**Fix.** Change the example to `"variance": { "total_range": 0.0 }`, and either rename
`per_dimension_max_minus_min` to whatever a consumer will read or state plainly that nothing
consumes it today and it is recorded for humans only. Durability: assert in the smoke suite that
the field name appearing in `evals/baseline/README.md`'s JSON example matches the jq path in
`bin/edm-compare-eval` (the two strings must be equal), with a positive control.

### F4 [P2] plugins/edm/evals/fixtures/tiny-svc/README.md:38-42 -- names `du -sk` as the CI enforcement, but the job measures git-tracked bytes only

**Doc says.** "The fixture plus `expected.json` stays under the 100KB budget for
`plugins/edm/evals/` (EDMV3-25 AC, EDMV3-80). Nothing in `bin/` measures directory size; the
enforcement is the `lint:file-type-ban` job in the repository-root `.gitlab-ci.yml`, which runs
`du -sk plugins/edm/evals/` and fails the blocking `lint` stage above 100KB."

**Code does.** `.gitlab-ci.yml:342-359` runs `git ls-files -- plugins/edm/evals`, sums `wc -c`
per tracked file, and ceiling-divides to KB. The token `du` does not appear anywhere in
`.gitlab-ci.yml`. The scopes differ materially: `du -sk` counts untracked content, including
`plugins/edm/evals/runs/` eval output, which the real check deliberately excludes and announces
at :360 ("eval runtime output under plugins/edm/evals/runs/ is retention-managed separately by
CI artifacts and is not counted in this tracked-bytes budget"). A contributor reproducing the
documented command locally after any eval run gets a number far over 100KB and concludes they
broke the budget.

**Fix.** Replace the `du -sk` clause with the tracked-bytes description and state the `runs/`
exclusion, e.g. "which sums `wc -c` over `git ls-files -- plugins/edm/evals` (git-tracked files
only; untracked eval output under `runs/` is excluded) and fails the blocking `lint` stage above
100KB."

### F5 [P2] plugins/edm/CLAUDE.md:880-886 -- the CA-407 durability note names the wrong suite file and understates what is actually machine-checked

**Doc says.** ":880: **Durability (G25/CA-342):** `wave6-smoke.sh` carries a computed assertion
(grep -c the real `schema_at_least(` call sites in `bin/edm-state` against the count named in
this paragraph) ... :883: CA-407: `grep -c` yields a single total, so only that total count is
machine-checked ... the comment-presence split is not machine-checked at all."

**Code does.** Two separate inaccuracies:
1. The assertion is in `bin/tests/wave7-smoke.sh:4290-4305`, not `wave6-smoke.sh`.
   `wave6-smoke.sh`'s only mention of `schema_at_least` is a passing prose reference at :2299 --
   it carries no assertion on this at all. A maintainer following this pointer to update the
   guard would look in the wrong file.
2. THREE things are machine-checked, not one: call-site total `-eq 6` (:4296-4299), canonical
   `# requires schema_version >= ` comment-line total `-eq 5` (:4300-4303), and CLAUDE.md
   literally containing the string "Four of the six" (:4304-4305). So "only that total count is
   machine-checked" and "the comment-presence split is not machine-checked at all" both
   understate the guard. What is genuinely unchecked is the MAPPING from comment to call site --
   nothing verifies that the five comments sit at four of the six call sites.

The substantive counts themselves are correct and I re-derived them: six `schema_at_least "`
call sites (`bin/edm-state:2166, 2284, 2342, 2869, 3704, 4409`), five `# requires schema_version
>= ` comments (`:2273, 2335, 2866, 3654, 3695`), four call sites carrying one, and the two
without are `cmd_approve_gate`'s precheck (:2166) and `cmd_audit_converged` (:4409) -- exactly as
:861-876 states.

**Fix.** `wave6-smoke.sh` -> `wave7-smoke.sh`. Restate the caveat as what is true: "three totals
are machine-checked (call sites, canonical comment lines, and this paragraph's own 'Four of the
six' wording); what is not checked is WHICH call sites carry the comment, so an edit that removes
the comment from one call site and adds one elsewhere leaves every total unchanged."

### F6 [P2] plugins/edm/bin/tests/wave7-smoke.sh:7835-7842 -- the G10/CA-340 allowlist's justification describes text that CA-406's fix deleted, and the allowlist entry is now inert

**Doc says.** :7836-7838: "... and the ticket-provenance quote inside edm-check-grants, around
line 419, which quotes a ticket's own hooks.json line-117 wording verbatim, not asserting a live
fact) -- an explicit allowlist keeps both exempt even if a future widening of this regex would
otherwise catch them."

**Code does.** `bin/edm-check-grants:415-421` no longer contains any `hooks.json:117` quote --
CA-406 rewrote it to "Each 'prompt' value is stored on one physical line in this file, so the raw
line number doubles as the citation -- naming the same site (hooks.json's
SubagentStop/edm-implementer prompt) the ticket's own comment in bin/edm-state now cites by anchor
rather than line number (CA-406)". I verified that NO line in `bin/edm-check-grants` matches
`g10_citation_regex` (:7840) today, so `g10_allowlist_2` (:7842) filters nothing out of the live
scan at :7851-7852. Its only remaining exercise is the synthetic string fed to the filter at
:7874, which now asserts the filter suppresses a line shape that no longer exists in the tree.

**Fix.** Either (a) drop `g10_allowlist_2`, its use in `g10_filter_allowlist` (:7848), and its
synthetic control line (:7874), and reword :7834-7839 to name only `.gitlab-ci.yml:198`; or
(b) keep it as a deliberate standing exemption and say so honestly: "kept as a standing
exemption though nothing in `bin/edm-check-grants` matches this ban today -- CA-406 removed the
citation it was originally written for."

### F7 [P2] plugins/edm/evals/baseline/README.md:11-13 -- the `run-eval.sh:309-327` line-range citation has already re-staled, in the very sentence that boasts about correcting its predecessor

**Doc says.** ":11: `run-eval.sh:30-32,:309-327` -- the `ANTHROPIC_API_KEY` env row and the 'Two
sanctioned auth paths' comment plus the actual gate, not the help-text and retention-block ranges
a prior version of this citation pointed at".

**Code does.** `:30-32` is still correct (the `ANTHROPIC_API_KEY` row in the Environment help
block). `:309-327` is not. In the current file, :309-313 is the tail of `run_with_timeout`
(`wait "$pid"` ... `}`); the "Two sanctioned auth paths" comment is at :315-320; and "the actual
gate" -- the `die "no working Claude auth: ..."` -- is at :332, seven lines PAST the end of the
cited range. The G45 timeout-probe insertion at :326-331 pushed it out. So the citation starts
six lines early inside an unrelated function and stops before the thing it claims to cite.

Note this file is not caught by the G10/CA-340 tree-wide ban: that scan's second grep
(`wave7-smoke.sh:7845`) requires the hit line to begin with `#`, and this is markdown prose.

**Fix.** Cite by anchor, matching the form CA-315 and CA-406 already standardized: "run-eval.sh's
`ANTHROPIC_API_KEY` row in the `# Environment (all optional overrides):` help block, and its
`# --- Environment / credential requirements` section -- the 'Two sanctioned auth paths' comment
and the `no working Claude auth` die() below it."

### F8 [P2] plugins/edm/bin/tests/wave7-smoke.sh:223-225 -- CA-408 still open; the section banner for the T03 block has only a trailing divider (prior round attributed this to bin/edm-state, where no banner exists)

**Doc says / structure is.**

    213  # =================================================================================
    214  # EDMV3-T04 -- README install path regression guard (AC6). ...
    216  # =================================================================================
    ...
    223  # EDMV3-T04 end
    224  # EDMV3-T03: bin/edm-check-grants -- four-source grant/instruction contract checker
    225  # =================================================================================

**Code does / convention is.** Every other block banner in this file uses divider / header /
divider -- see :213-216, :2148-2153, :6658-6663, :7797. Here the T03 header at :224 has no
leading divider, so the divider at :225 reads as closing the T04 block rather than opening T03's,
and the `# EDMV3-T04 end` marker is visually fused into T03's header. A reader scanning block
boundaries (or an awk range extraction anchored on the divider, which this suite uses elsewhere)
attributes :224 to the wrong block.

**Corrected attribution.** `bin/edm-state` has zero `^# =====` banners; the prior round's file
attribution was wrong. Re-flagged here rather than closed.

**Fix.** Insert one `# =================================================================================`
line between :223 and :224.

### F9 [P2] plugins/edm/WHATS_NEW.md:26 -- "now on round 7" is stale as of this round, and will restale every round

Adjacent to the declared scope (new untracked file at the plugin root, operator-facing).

**Doc says.** ":25-26: None of this is aspirational -- it's what's already running in v3.1.0,
with the final hardening pass (an 11-lens code audit, now on round 7) still tightening loose ends
as they're found."

**Code does.** This is round 8. A per-round counter embedded in release-notes prose has no owner
to bump it and no assertion behind it; it was already wrong the moment round 8 started.

**Fix.** Drop the number: "with the final hardening pass -- a recurring 11-lens code audit --
still tightening loose ends as they're found." Every other claim in this file checks out
(orchestrator SKILL.md is 205 lines, so "under 300 lines" holds; `approve-gate` does reject
anything outside 1/2/3/3.5/code-audit per `bin/edm-state:2251`; the `--accept-p2-debt` command
line at :51 matches `bin/edm-state`'s help at :18).

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L6-N1 | plugins/edm/CHANGELOG.md:7 | `## [3.1.0] - 2026-07-28` carries a Unicode em dash, but CHANGELOG.md is an explicitly documented carve-out from the shipped-surface ASCII sweep (`wave7-smoke.sh:4844-4846`, "project history, not rewritten retroactively -- the same carve-out bin/vocabulary-allowlist.txt makes"). Filter 1/3: sanctioned exception with a named owner. |
| L6-N2 | plugins/edm/bin/tests/run-all.sh:71 | "wave7-smoke.sh, ~830 assertions" undercounts (roughly 980+ assertion call sites today: 606 `check`/`check_absent` plus 376 explicit `pass` branches). Filter 1: the `~` marks it approximate, the number is illustrative of "a big suite silently vanishing", and no behavior depends on it. |
| L6-N3 | plugins/edm/CLAUDE.md:285 | "This section's heading string, `## Mermaid diagram conventions (canonical)`, is referenced by name from the eleven touch points" -- all eleven touch points actually reference the truncated `CLAUDE.md Sec."Mermaid diagram conventions"` (no `(canonical)` suffix), so renaming only the suffix would break none of them. Filter 1: the count is exactly right (11 distinct files verified: 4 skills, 5 agents, 2 pattern docs) and the guidance errs conservative. |
| L6-N4 | plugins/edm/bin/edm-compare-eval:82 | Refusal message says "two scorer versions can weight dimensions differently" while evals/README.md:218 documents `total` as an UNWEIGHTED arithmetic mean. Filter 1: "can" states what a future scorer version is free to do, not a claim about the current one; the operative instruction ("re-capture the baseline") is correct either way. |
| L6-N5 | plugins/edm/evals/README.md:7 | "This directory has three parts, built across two tickets" sits above a two-row table. The three parts (fixture, driver, scorer) are all named inside those two rows, grouped by owning ticket. Deliberate grouping, not a miscount. |
| L6-N6 | plugins/edm/CLAUDE.md:237-238 | `Sec."10. Convergence gate"` names an ordered-list item (`10. **Convergence gate**`, skills/code-audit/SKILL.md:141), not a `##` heading, and the quoted name is line-wrapped mid-quote. Filter 1/3: resolves unambiguously for a human, and `docs/canonical-sections.md:35` carries byte-identical text by generation (`bin/edm-sync-canonical-sections`), so it is not independently editable. |
| L6-N7 | CLAUDE.md (repository root):7 | "runs a two-tier validate stage against its plugin manifest and tracked initiative state" -- initiative state is actually validated in the `test` stage (`test:state-validate`), not the `validate` stage. Filter 2: deliberate one-sentence simplification in a repo-level overview; the plugin's own CLAUDE.md carries the exact stage table. |
| L6-N8 | plugins/edm/README.md:87-103 | The "Observed behaviour (manual QA, wave A)" table is dated against Claude Code 2.1.220 while :55 says 2.1.x and `.gitlab-ci.yml` pins the CLI at 2.1.226. Filter 1: the note explicitly dates and versions itself, states it is a documented-behaviour derivation rather than a live capture, and asks for human reconfirmation. |
| L6-N9 | plugins/edm/agents/edm-audit-docs.md:98 | This lens's own agent definition ships the `## JSONL Line Format` section, and its schema line is byte-identical to the launch template's at skills/code-audit/SKILL.md:303. No drift between the two authoritative statements of the schema. |

## Cross-references verified clean (no finding)

Recorded so a later round does not re-spend the effort: `hooks/hooks.json` has exactly nine
command-type hooks, matching `.gitlab-ci.yml:262`; `edm-state --help` documents exactly 39
subcommands, matching CLAUDE.md's list and the dispatch table; all 14 skills set
`disable-model-invocation: true`, matching README.md:126; `/edm:test`'s "10 specialist agents
(planner, scaffold, 7 writers, coverage auditor)" is exact; the 11 lens agents named in
README.md:140 all exist; `compute_cost_usd`'s "eight explicit arms" and "`unknown` is arm 6 of 8,
between `*haiku-4-6*` and `*sonnet-4-7*`" (CLAUDE.md:492-509) match `bin/edm-state:470-508`
exactly; the `.gitignore` block in README.md:227-234, `bin/edm-init:171-178` and
`bin/edm-state:2030-2037` are all identical; `docs/audit-patterns/README.md:52`'s "three existing
HITL gates" and :71-78's six `update-patterns` call sites all resolve; all 12 `bin/` helpers and
`evals/` drivers carry the EDM-HELP sentinel block and source the shared `print_help`; the three
`test` jobs do carry `needs: ["lint:bash-syntax"]`; `docs/EDM_Plugin_Presentation.pptx` and
`docs/EDM_Plugin_User_Guide.docx` exist at the paths README.md:32-33 links.
