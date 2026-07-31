# EDMV3 - Session Handoff

> **Last updated**: 2026-07-31T22:56:29Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMV3`

## Current Status

- **Phase**: Phase 6 - Implementation
- **Gates approved**: 3 of 3
- **Last gate**: Gate 3 - approved 2026-07-27T01:43:50Z by darryl.porter
- **Product**: edm
- **Description**: prompt-streamline
- **Next action**: Phase 6 in progress - run `/edm:orchestrator EDMV3` to continue, then `/edm:test EDMV3` when all tickets pass QC

## Resume Point

- **Phase**: Phase 6 - Implementation
- **Step**: 6.code-audit-round-1-non-convergent
- **Last command**: `edm-state audit-converged EDMV3  (exit 1, NOT CONVERGENT)`
- **Last decision**: Code-audit round 1 (full, 11 lenses) complete and NON-CONVERGENT. Ledger: 132 findings after cross-lens dedup -- 4 P0, 40 P1, 60 P2, 28 NOTED. Four fixed in-round (both arithmetic-context injection sinks CA-001/CA-003, the missing --lenses arg CA-004, the lost die interpolations); 100 remain open and ALL block, because BLOCKING_FILTER includes open P2. Next action is remediation, not the gate: work REMEDIATION.md in code-audit/pass-1_2026-07-28/, then re-run a full round. The convergence gate stays unapproved -- only an explicit human Approve may set code_audit_converged, and there is nothing to approve while 100 findings block. Three root causes carry most of the volume: the ignore-marker/fence rewrite three hand-copies did not follow (2 of them in blocking CI jobs), status captures that structurally cannot observe failure, and prose describing pre-change code in files that are themselves the contract.

**Pending artifacts for Phase 6 - Implementation**:

_(implementation in progress -- track individual ticket status)_

> Copy-paste to resume: `/edm:orchestrator EDMV3`

## Lifecycle & Mode

- **Mode**: standard
- **Lifecycle mode**: standard
- **Compliance**: false
- **Implementation mode**: standard

## Open Code-Audit Findings

not converged: 100 blocking finding(s) for EDMV3 (P0=1 P1=39 P2=60) of 132 considered, 28 NOTED excluded:
  CA-002 P0 cmd_update_patterns heading-targeted insertion has zero coverage and its only test is satisfied by an implementation that does nothing, while the test resolves the pattern file from committed plugin source
  CA-005 P1 hardcoded sed -n 2,45p help range truncates the script's own Output format and Exit codes contract, repeated in run-eval.sh:55 and score-artifacts.sh:100, alongside a four-way split in help shape and two bin/ scripts with no help at all
  CA-006 P1 test:smoke-bash32 runs apt-get on the Alpine-based bash:3.2 image, so before_script always fails, the job never reaches script, and the declared end-to-end proof of the bash 3.2 constraint does not exist
  CA-007 P1 failure-status captures that cannot observe failure -- GitLab's inherited set -eo pipefail aborts before rc=$? at :327, :474 and :531, and run-eval.sh:437-455 expands its containment check inside a heredoc so an error reads as clean
  CA-008 P1 the class-2 PCRE branch reads three fields from a two-field grep -n, so ignore-marker and code-fence suppression is inoperative for the unicode class on GNU grep -- the branch CI takes -- while macOS takes the correct fallback
  CA-009 P1 the two mirrored ignore-set copies anchor fences at column 1 while the canonical linter de-indents, so content in roughly 60 indented fences is suppressed by the linter and reported by the blocking lint:vocabulary job
  CA-010 P1 the mirrored VERBATIM claim in two checkers names build_ignore_set, which no longer exists in the file it names, and the one assertion guarding the mirror greps for that dead symbol so it pins the drift
  CA-011 P1 the commit-lint hook branches on any non-zero status, so an exit 2 misinvocation reports Fix artifact violations on a clean tree, and the honest exit-1 violation path may not block a PreToolUse hook at all
  CA-012 P1 the compute_cost_usd gap subsection documents the removed bare family wildcards and states no warning fires in exactly the case that now warns on every run, inverting the diagnostic for a reader
  CA-013 P1 EDMV3-116's negative branch is half-landed -- the generated file has zero prompt-surface consumers, EDMV3-54 AC and T42 AC4 still mandate the reference form D22 proved does not resolve, and the remaining work has no named ticket
  CA-014 P1 the mktemp template places .json after the Xs, which BSD/macOS mkstemp rejects, so --self-test dies on the declared hard-target platform and takes wave7-smoke.sh and run-all.sh down with it
  CA-015 P1 two hand-rolled .tmp.$$ writers land inside tracked directories with no trap -- the pattern docs at :3565 and the findings ledger at :2813 -- and $$ is not a safe uniquifier across containers sharing one repo
  CA-016 P1 the aggregator's result accounting cannot distinguish a crashed suite from a green one -- an aborted suite contributes 0 0 beside FAILED SUITES, a silent suite exiting 0 reports PASS 0 0, and a suite matching neither summary parser also reports 0 0
  CA-017 P1 the build_line_classes header enumerates two of the three emitted classes (marker is undocumented), contradicts itself four lines later, claims the 40 percent budget is met by construction against the recorded history, and misstates why the block escape valve works at :136
  CA-018 P1 three restated severity tables have diverged from the canonical scale, and the synthesizer's -- the agent that assigns ledger severity -- is the abolished legacy P1/P2/P3 definitions relabelled, so a canonical P1 missing requirement matches no row of it
  CA-019 P1 the scorer's copy of the Mermaid rule has diverged from the canonical implementation seven ways and awards full marks to two of the five committed invalid fixtures the rule exists to catch
  CA-020 P1 every lens Output contract requires lens-L{N}.jsonl and declares it authoritative, but the launching skill names only the markdown, so the ledger is built from prose -- this round is a live instance with eleven .md files and zero .jsonl
  CA-021 P1 update-patterns writes to the plugin cache at ${script_dir}/../docs/audit-patterns/ while the three gate curation blocks grep a cwd-relative docs/audit-patterns/*.md that does not exist in a project cwd, so every stub stays pending-review forever
  CA-022 P1 four prompt surfaces instruct a cwd-relative Read of docs/templates/ticket-size-legend.md and cross-cutting-ac.md with no plugin-root anchor and no defined failure behaviour, so the practical outcome is a re-authored legend
  CA-023 P1 the commit-lint hook hardcodes ^SRD/ and bakes the same one-level assumption into its awk field indices, so a project that relocates srd_root silently loses all commit-time artifact enforcement
  CA-024 P1 the new blocking lint:shellcheck job runs unconditionally over bin/* and fails on five pre-existing deliberate word-splitting sites that carry no disable directive and that quoting would break
  CA-025 P1 the mkdir fallback spin-lock never checks its pidfile with kill -0, so one SIGKILLed run bricks every later mutation including the Stop and PreCompact hooks; nested acquisition also clears an outer trap and the two branches disagree on subshell semantics
  CA-026 P1 cmd_checkpoint reads prefix with no state-file guard and no validity check, so a merge-conflicted state file creates SRD/unknown/ and aborts the sweep under set -e, silently ending checkpointing for every later initiative behind a hook that ends in || true
  CA-027 P1 write_handoff_internal truncates HANDOFF.md in place and writes the preserved Notes last, so a hook timeout between the two loses teammate-facing notes permanently; the notes filter also deletes every blank line and truncates at the first user heading
  CA-028 P1 the open form of record-partial-verdict overwrites partial_verdict_map[$tk] unconditionally, so a remediation loop that re-opens PARTIAL destroys the FAIL closure record the AC4 re-closure logic exists to preserve
  CA-029 P1 the two lock patterns name .edm-state.json.lock and .lockd while with_state_lock derives .edm-state.lock and .lockd from lockbase, so neither matches, and the flock file is never unlinked on any path
  CA-030 P1 the canonical-sections case appends to the tracked docs/canonical-sections.md and restores it with no trap, so any interrupt in a window of tens of seconds leaves a stray line in a tracked file plus an orphaned backup
  CA-031 P1 both documented eval defaults are wrong -- 900s against the real 2700s and $2 against the real $15 -- and the same file contradicts itself at :233, so an operator setting a budget from this line kills a real run before the audit phase finishes
  CA-032 P1 plan is the only artifact-writing phase skill without an Edit grant, yet Gate 1 performs the same in-place decisions.md append Gate 2 does with Edit, forcing a whole-file reconstruction of a file it did not author
  CA-033 P1 six ACs state their verify command as a grep for a literal wave-suite token in .gitlab-ci.yml that T21 AC5 requires to be absent, so all six return zero hits and cannot pass; D19 amended two of them in code only and never named the other four
  CA-034 P1 T22 AC8 still requires the driver to exit 2 without ANTHROPIC_API_KEY after D20 replaced that gate with two sanctioned auth paths, so its verify command starts a real costed run instead; run-eval.sh:23 and baseline/README.md carry the same stale contract
  CA-035 P1 four assertions are structurally incapable of failing -- an empty expected substring covering T52 AC2, an else branch passing on any non-scoped value for AC4, a sort -u pipe to wc -l that is always 1, and a dimension check that recomputes the scorer's own arithmetic
  CA-036 P1 unguarded zero-match grep -c in assignments abort the suite instead of failing it under set -euo pipefail, at :1652, :2146, :1458, :1567, :2048 and ten further sites in wave6, so the regression each exists to catch ends the run with zero failed assertions
  CA-037 P1 roughly two dozen zero-count assertions carry no positive control, so a misspelled needle or a wrong path is indistinguishable from the invariant holding -- including the --force absence check guarding the single most load-bearing product invariant
  CA-038 P1 the fence-indentation fix has no test in either direction -- the 16-file corpus contains zero indented fences and every fixture puts its fence at column 0 -- so reverting the change keeps the suite fully green
  CA-039 P1 three of the scorer's five dimensions never execute against the synthetic fixture (mermaid, coverage-map, and the vague-AC detector's positive case) and the two that do carry no expected-value assertion, so an inverted dimension would score 100 for every input
  CA-040 P1 convergence_exempt is untested at both consumers, including the deliberate asymmetry that approve-gate code-audit stays refused under fast-track, so an edit routing approve-gate through the helper for consistency would open a gate bypass silently
  CA-041 P1 the pricing tests assert frozen-not-overridable only as greater than zero, cover just the opus previous-generation arm, and leave the documented in-family mispricing behaviour with no test at all
  CA-042 P1 check_state_unchanged has two vacuous-pass modes across 49 hand-built call sites -- a missing file hashes to the literal absent so a typo compares absent to absent, and the command's exit code and output are discarded entirely
  CA-043 P1 an AC5 assertion greps git log rather than tree state, so it is vacuous on a shallow clone, a squash, a rebase or outside a work tree, and its 2>/dev/null || true converts every one of those into a pass
  CA-045 P2 the test suites create roughly 30 scratch trees under a hardcoded /tmp with no trap on any line of wave7-smoke.sh and nine wave6 trees outside the trap-covered TMP, so a signal leaks megabytes and a fake HOME shaped like a real one
  CA-046 P2 each pinned digest is spelled out twice -- alpine at :42 and :353, node at :461 and :499 -- contradicting the anchor comment's single-line-change claim and leaving the blocking validate:manifest job on a stale digest after a partial refresh
  CA-047 P2 the closure message reads ${already_closing_verdict:-PARTIAL} on a path where that variable is necessarily empty, so a PASS or FAIL entry is reported as was PARTIAL; it also reads .closing_verdict where the open shape's verdict lives in .verdict
  CA-048 P2 three gate curation blocks prescribe a literal shell grep under a rule that absence is authoritative, and none of the three grants Bash(grep *), so a denied grep is indistinguishable from zero matches and curation is silently lost at every gate
  CA-049 P2 the plugin root is resolved from $0 rather than BASH_SOURCE in two bin/ scripts and one suite, and PLUGIN_DIR is derived four different ways with two names, so a sourced script computes the wrong root
  CA-050 P2 build_ignore_set exists as byte-identical 35-line copies in two checkers, is_ignored_line three times and report_violation three times, with no shared library -- this duplication is the root cause behind CA-009 and CA-010
  CA-051 P2 audit-round-start --lenses with a degenerate value such as a bare comma passes the non-empty guard, then grep -v selects nothing and pipefail plus set -e terminate the script with exit 1 and no message, handing the caller an empty round number
  CA-052 P2 compute_cost_usd passes -v or=$out_rate to awk, and gawk reserves or as a bit-manipulation built-in and refuses to bind it, so every phase-complete and audit-round-complete fails fatally on any host where awk is gawk
  CA-053 P2 a comment describes --bare as what makes AC8 true at the CLI level while the NOTE at :288 says the opposite and explains its removal, and the flag appears nowhere in the claude -p invocation
  CA-054 P2 the prototype) case arm emits output byte-identical to the *) fallback immediately below it, since ${mode} expands to prototype there -- pure duplication with no behavioural difference
  CA-055 P2 the update-patterns read-dedup-insert-mv sequence takes no lock on the pattern file, so two converging code audits resolving the same document lose one another's insertion while both report N new findings appended
  CA-056 P2 both the grep -qxF pre-flight and awk's heading equality test are fence-unaware and first-match-wins, so a pattern doc documenting its own Append Schema inside a fence gets the entry spliced into the fenced example and trips the four-heading contract check
  CA-057 P2 in_fence is a single boolean with no END reconciliation, so an unterminated fence marks every later line ignored and a four-backtick fence inverts the state; split() also leaves \r, so a CRLF file never matches lang == mermaid and class 4 never fires
  CA-058 P2 collect_md_files has no -type f and no -print0, so a directory or dangling symlink named *.md propagates awk exit 2 and the hook reports violations on a clean file; line sets also ride in the environment, so a large generated artifact hits E2BIG and class 4 reports zero
  CA-059 P2 the audit round number is echoed from a re-read after the lock releases, so two concurrent starts can return the same round and two rounds write into one pass directory; the same check-then-lock shape voids two once-only invariants and cmd_init takes no lock at all
  CA-060 P2 both token-read branches use jq -s, so one torn line in a live-appended session JSONL fails the whole program and silently falls back to the whole-directory sum that T52 AC1 removed, or records zero tokens which then reads as a blocking ZERO_TOKENS anomaly
  CA-061 P2 gate-check is documented read-only and is what five hooks call, but for a legacy initiative it appends an undeduplicated degraded_checks row and takes the write lock, so session-start output grows linearly and a read-only checkout fails
  CA-062 P2 the archive move has no destination-exists guard, so git mv refuses and the || mv fallback moves the source inside the existing directory, producing a nested path invisible to list_state_files while printing success and exiting 0
  CA-063 P2 eval:nightly declares no timeout and inherits the 60-minute default while the driver allows 2700s per phase across three phases, so one slow phase replaces the documented exit-4 contract with a GitLab timeout indistinguishable from a hang
  CA-064 P2 an unparseable or zero-byte run.json defaults to complete: true, and write_partial_artifacts truncates before writing, so edm-compare-eval compares a partial run against the baseline -- exactly what the handshake exists to prevent
  CA-065 P2 the staging mktemp is trapped but the tracked destination is written with a non-atomic cp, so a signal or ENOSPC leaves half-written the one generated file that both --check and a smoke case byte-compare
  CA-066 P2 evals/runs/ has no retention policy and sits inside the path the blocking 100KB du gate measures, so one local eval run makes the local reproduction of that gate fail; it survives in CI only because GIT_CLEAN_FLAGS wipes ignored files
  CA-067 P2 the attribution pattern file is created with no trap inside scan_md_files, which runs once per initiative in --all mode, so the leak window is entered N times per run on the hot commit-hook path
  CA-068 P2 the AC8 row still presents git diff --stat shows zero changes as the proof of PASS while the same file declares that evidence invalid at :75, and four Added bullets appear twice byte-identically inside one version entry
  CA-069 P2 three operator messages are wrong: the convergence waiver names mode as the cause when the second trigger leaves mode standard, the archive refusal says remediate the blocking findings for two causes that need ledger repair, and approve-gate's usage names one of three legal forms
  CA-070 P2 three CLAUDE.md contracts are stale: tokens.cache_write is a field nothing writes, the model and effort paragraph omits verify-runtime and the three test skills, and the schema_version contract says cmd_init writes the running wave when it writes the literal 1
  CA-071 P2 the header states every image entry below is pinned to a sha256 digest, which is false for test:smoke-bash32 260 lines later, and the failure message at :177 ends in a colon promising a list it never prints
  CA-072 P2 two comments each claim sole authorship of the same 39,872 ms measurement, which the CHANGELOG attributes to both per-line fork loops and records re-profiled at 70,168 ms
  CA-073 P2 --all-lint prints a default initiative count of 50 it never measured, in a harness whose header states no numbers are invented, and the --mermaid-ratio comment cites a short-circuit the mode deliberately disables for every file it measures
  CA-074 P2 the nine bin/ helpers diverge on three conventions -- die() defaults to exit 1 in one and 2 in its siblings, edm-validate-prefix inverts the family's exit-code meanings, and two scripts run set -uo without -e with only one having a reason
  CA-075 P2 both validate jobs declare no needs: at all, so they wait for the entire lint and test stages despite depending on no job in either, contradicting the stated rationale for the stage split
  CA-076 P2 lint:grants and lint:vocabulary install git, which neither checker invokes and neither comment justifies; two lint jobs print no terminal job-named verdict where the other two do; and :234 hardcodes all five library docs inside a dynamic loop
  CA-077 P2 code-audit runs update-patterns at sub-step 10.5 after Approve, where both sibling audit skills run it before their gate, so a converging round leaves its own stubs pending-review with no later gate to curate them
  CA-078 P2 Gate 3 and the Convergence gate append nothing to decisions.md while Gates 1 and 2 do, with nothing stating the omission is intentional, so a reader treating decisions.md as the initiative ledger gets two of four gates
  CA-079 P2 non-ASCII appears in six test files including run-all.sh:50, which the blocking test:smoke job prints to stdout on every pipeline, so the aggregator violates on stdout the ASCII rule its own suite asserts for every committed artifact
  CA-080 P2 two of the eleven lens definitions carry a False-Alarm-Filter lead-in and trailer the other nine dropped, in two non-matching phrasings, and edm-audit-logic renders the canonical-severity clause as a bulleted field where ten render a bare sentence
  CA-081 P2 the test-writer N/A exit tokens are not uniform or substring-distinguishable -- e2e carries a bare N/A that is a prefix of all five siblings, and a11y's bottom-of-file string differs from its own Step-0 token and prefixes component's
  CA-082 P2 state_file_for validates prefix against a slug regex to prevent path traversal and then interpolates two unvalidated env vars into the same path, so EDM_PRODUCT with a traversal value writes outside the SRD root
  CA-083 P2 cmd_watch_impl sets last_sha with || echo '' and swallows every git error in the poll loop, so armed outside a worktree or before the first commit the monitor runs the whole session emitting nothing indistinguishable from no ticket commits
  CA-084 P2 timing.sh carries an undeclared hard perl dependency for Time::HiRes while asserting perl is present on every targeted image, and neither alpine:3.20 nor bash:3.2 ships perl, so the harness cannot run where its budgets are certified
  CA-085 P2 every blocking job's before_script is an unpinned network package install, and the guard that forbids network calls in blocking jobs greps only curl and wget and resets on a pattern that cannot match a job name containing a colon, so it passes for the wrong reason
  CA-086 P2 the eval tool allow-list grants Bash(jq *) while the comment above claims nothing grants unrestricted shell access and the run cannot reach outside the scratch tree, and this repository documents the Bash matcher as a literal prefix match
  CA-087 P2 the five UserPromptExpansion hooks apply no charset filter to $ARGUMENTS, unlike the PreToolUse hook which filters its derived prefixes, and the same line blocks expansion with a bare exit 1 and no message when $ARGUMENTS is empty
  CA-088 P2 a filename-derived token is interpolated unescaped into a grep -E pattern, so a run directory containing a file literally named with a glob metacharacter matches the wrong rows and dimension 5 scores against the wrong count
  CA-089 P2 the script was built despite T39's explicit do-not-build-speculatively prohibition and asserts the inverse of what EDMV3-52 and T39 AC7 specify -- an anti-duplication guard rather than a sync checker -- with no amendment to the spec
  CA-090 P2 T06 AC10 names three state fields as code_audit_converged_* while the code writes code_audit_gate_*, and the AC's verify command only checks the boolean's type so the naming divergence is invisible to the test meant to close it
  CA-091 P2 T23 AC13 requires the baseline to be captured before the first wave-B commit, a precondition permanently gone now that waves B and C have shipped, and D23 records the missing baseline without ever naming T23 or its temporal clause
  CA-092 P2 the ticket pack contradicts itself on which SRD revision its coverage map derives from -- the header says v1.3.0 while the metadata table and the Coverage Map opening both say v1.2.0
  CA-093 P2 the mode half of the convergence exemption including the legacy null default is written a third time outside convergence_exempt, and its comment says it mirrors cmd_archive's identical guard when cmd_archive no longer has that guard
  CA-094 P2 seven further identical whole-tree --all lint scans and 13 identical edm-check-grants invocations run in one suite with nothing mutating the tree between them, and a per-ticket failure is falsely attributed to that ticket
  CA-095 P2 one shared line in all eleven lens definitions cites SKILL.md:40 for a mkdir -p that is on line 45, so one fact duplicated eleven times is wrong in all eleven simultaneously; two more stale citations sit in edm-check-grants
  CA-096 P2 the same 15-line standalone-checker invocation block appears twice differing only in script name, variable prefix and label, so adding a third checker means a third copy
  CA-097 P2 the orchestrator's Jira intake calls bare unnamespaced MCP tool names with no availability probe while push-jira uses the configured namespace and probes first, so one of three documented intake shapes is unreachable on any install lacking that server
  CA-098 P2 step 3 resolves INIT_DIR layout-aware but the lens launch template hands lenses a legacy-flat srd_root/PREFIX path that does not exist for a product-scoped initiative, silently starving L9 of the SRD and ticket pack it is marked as requiring
  CA-099 P2 seventeen assertions use needles too short to fail -- mode matches model and modes, and nine in-layout checks only prove a filename appears somewhere in a 1000-line file -- while their labels claim behaviours the words do not establish
  CA-100 P2 the four-way lint split is asserted by job name only, with nothing asserting the jobs exist, are in the lint stage, collectively invoke every checker, or carry no allow_failure, and :3334 records the split as an unfixed gap while :3318 treats it as landed
  CA-101 P2 strip_entities' explicit 1..10 character walk is never tested at either boundary, and the parenthesised and curly label spans have no valid counterpart proving a legal label with a trailing terminator passes
  CA-102 P2 a dozen assertions are coupled to transient state or exact wording -- hardcoded absolute line ranges into files other tickets edit freely, baseline counts that will drift with no source-of-truth named, and an alternation count satisfiable by one field appearing four times
  CA-103 P2 the shared-lint invariant that nothing between the capture and the T48 block may mutate the tree or change EDM_SRD_ROOT or cwd is enforced by a comment only, and five ticket blocks depend on it
  CA-104 P2 the tiering matrix's only numeric boundary is untested -- --self-test covers 90, 100 and 70 percent so changing >= 80 to > 80 passes all three unchanged -- and run_matrix exits 0 with no output on an empty agents array or a jq error

## Gates

- Gate 1 - approved 2026-07-25T20:40:25Z by darryl.porter
- Gate 2 - approved 2026-07-25T22:30:47Z by darryl.porter
- Gate 3 - approved 2026-07-27T01:43:50Z by darryl.porter

## Artifact Checklist

| Artifact | Status |
|----------|--------|
| `./SRD/edm/EDMV3__prompt-streamline/planning.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/srd.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/audit-srd.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/tickets/README.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/tickets/audit.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/architecture.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/decisions.md` | [present] |
| `./SRD/edm/EDMV3__prompt-streamline/ROLLBACK.md` | [absent] (on-demand) |
| `./SRD/edm/EDMV3__prompt-streamline/exec-report.md` | [absent] (on-demand) |

## Key Decisions Made

_(none recorded yet - decisions are captured at Gate 1)_

-> See full decision ledger: `./SRD/edm/EDMV3__prompt-streamline/decisions.md`

## How to Resume

1. Pull the latest branch - all EDM artifacts are committed
2. Open Claude Code in the project root
3. Run: `/edm:orchestrator EDMV3`
4. The orchestrator detects the existing initiative and resumes from **Phase 6 - Implementation**

## Notes

_(Add anything a teammate should know before resuming - context, blockers, preferences)_