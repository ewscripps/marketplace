# EDMV3 - Session Handoff

> **Last updated**: 2026-08-01T01:12:47Z by darryl.porter  
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
- **Last command**: `edm-state approve-gate EDMV3 code-audit (exit 1, refused after schema_version fix)`
- **Last decision**: Round 2 (full) synthesized: 91 blocking (1 P0, 13 P1, 77 P2), NOT CONVERGENT. User approved the Convergence gate anyway; approve-gate incorrectly succeeded because schema_version was still 1 (cmd_init default), which skips the code-audit precheck entirely (CA-182, new P0, filed). Migrated schema_version to 2, manually reverted the bogus code_audit_converged=true and its gate metadata (no cmd_set path exists for that field by design), and re-ran approve-gate to confirm it now correctly refuses. code_audit_converged is false; next action is remediation per pass-2 REMEDIATION.md, approved by the user, then a third full round.

**Pending artifacts for Phase 6 - Implementation**:

_(implementation in progress -- track individual ticket status)_

> Copy-paste to resume: `/edm:orchestrator EDMV3`

## Lifecycle & Mode

- **Mode**: standard
- **Lifecycle mode**: standard
- **Compliance**: false
- **Implementation mode**: standard

## Open Code-Audit Findings

not converged: 92 blocking finding(s) for EDMV3 (P0=2 P1=13 P2=77) of 182 considered, 40 NOTED excluded:
  CA-002 P0 cmd_update_patterns was rewritten onto with_state_lock, write_atomic and _splice_pattern_file but the prescribed insertion tests were never written -- the only runtime invocation seeds a duplicate so new_findings stays 0 and the whole write path is never entered, and it still resolves the pattern file from committed plugin source
  CA-005 P2 the truncating sed help range is gone from all named sites but the shared print_help was never created -- the sentinel extractor is now hand-copied twelve times in three incompatible shapes, edm-sync-canonical-sections still has no sentinels and keys its extractor on the literal set -euo pipefail line, and the prescribed CI ban on the hardcoded-range form was never added
  CA-007 P1 three CI status captures and the containment status capture are fixed, but the containment check still slices path from position 3 so a porcelain rename record R old -> new whose destination escapes SRD/ is scored as contained -- the one check that would catch the eval driver mutating the host tree
  CA-010 P2 the mirrored-VERBATIM comments were removed from both checkers but the one assertion guarding the shared-library boundary still greps edm-check-grants for the dead symbol build_ignore_set, passes on call sites, and its label still describes a mirroring relationship and attributes the helpers to the wrong file
  CA-011 P1 the commit hook still branches on any non-zero and still derives prefixes from staged paths it never checks resolve, so a staged initiative deletion exits 2 and blocks a clean commit; the exit-1-vs-exit-2 PreToolUse blocking semantics are still unsettled and CLAUDE.md now pins the unverified assumption
  CA-013 P1 EDMV3-116's negative branch is still half-landed -- the generated file has zero prompt-surface consumers under agents/ or skills/, srd.md:2846-2852 still mandates the reference form D22 disproved, the remaining work still has no named ticket, and CLAUDE.md:302 gates the edit on T42 which landed two waves ago
  CA-014 P2 the BSD-incompatible mktemp template is fixed but the trap is still RETURN-only so a die or SIGINT inside --self-test leaks, and the T61 AC11 divergence sweep at wave7-smoke.sh:759-770 still covers only bin/ and only four patterns, so the class can regress in evals/ unseen
  CA-016 P2 the CRASH, zero-assertion and no-summary branches landed and wave4b now emits the standard summary, but there is still no minimum-suite-count floor, so deleting or renaming wave7-smoke.sh drops 830 assertions and the aggregate reports ALL SUITES PASSED
  CA-017 P2 the budget claim, the self-contradiction and the wrong escape-valve mechanism are all fixed, but the shared-pass comment still undercounts, now two of four derived sets, and the help block's four-class list omits unterminated-fence which also exits 1
  CA-018 P2 the abolished legacy scale is gone, but the synthesizer and edm-srd-auditor still restate a lossy four-bullet scale one line after instructing Do not restate or adapt a local scale -- P0 drops architecturally wrong, P1 drops missing requirement, P2 drops nice-to-have
  CA-019 P2 the scorer's Mermaid rule body was brought into agreement by cloning the canonical awk verbatim rather than sourcing _edm-lint-lib.sh or extracting bin/edm-mermaid-rules.awk, leaving a 45-line unguarded duplicate whose fence recognition is still column-1 anchored and which honours no edm-lint-ignore marker, under a header that still says the sourceable file is not attempted here
  CA-022 P1 the two skills were anchored but the agent surfaces the remediation named explicitly were not -- edm-ticket-writer.md:27-29,36-37, edm-implementer.md:22-23 and edm-srd-writer.md:23 still read docs/... cwd-relative with no plugin-root anchor and no defined failure behaviour, and the agent is what runs at write time
  CA-023 P1 the commit-lint hook still hardcodes ^SRD/ and bakes the same one-level assumption into its awk field indices, so a project that relocates srd_root silently loses all commit-time artifact enforcement; the gap was documented at edm-lint-artifacts:44-46 but not fixed, and wave7-smoke.sh:3370 still asserts the literal hardcoded matcher
  CA-024 P1 seven shellcheck-disable directives landed and cover the round-1 sites, but the blocking job still loops unconditionally over bin/* against a comment claiming new/modified code only, and the unquoted ${include_archived:+...} pair in list_state_files carries no directive -- unresolvable without one green pipeline run
  CA-025 P2 stale-lock detection and trap save/restore both landed, but the flock branch still runs the locked body in a subshell while the mkdir branch runs it in the current shell, with the divergence documented nowhere and one docstring describing both
  CA-026 P2 the three per-file guards landed but the per-initiative body is still unwrapped, so a die or non-zero rmw_state ends the checkpoint sweep for every later initiative behind a hook that ends in || true; a state file whose .prefix mismatches its directory still creates a stray SRD directory
  CA-027 P1 HANDOFF.md is now written atomically, but the notes filter still deletes every blank line and truncates at the first user heading, and the read-render-write is still unlocked so two concurrent checkpoints lose one window's notes
  CA-034 P2 T22 AC8 and run-eval.sh now state the two sanctioned auth paths, but evals/baseline/README.md:9-10, :24 and :28 still assert the abolished ANTHROPIC_API_KEY-only contract in the closing command for T23 AC8/AC9/AC13, so the stale precondition is load-bearing
  CA-035 P1 the widened T42 AC4 regex requires a literal backslash on both sides so it matches only skills/srd/SKILL.md:182's escaped form -- the assertion reports exactly one quoting form while twenty unescaped references exist in the tree, a green suite over a real violation introduced by the round-1 remediation itself
  CA-037 P2 three of roughly two dozen zero-count assertions gained a positive control including the load-bearing --force check, but roughly twenty still carry none -- the duplicate --force check in wave6, the three T66 AC4 deleted-text counts, both code_audit_converged checks, and a mapfile regex that still cannot match mapfile<file
  CA-038 P2 only the clean direction of the fence-indentation fix is tested -- v12-indented-fence.md proves an indented plain fence suppresses, but no fixture proves an indented mermaid fence is still scanned, so reverting the half CHANGELOG.md:46 names as missed violations keeps the suite green; the em-dash half of v12 is also missing
  CA-039 P1 dimensions 3 and 4 now execute against the synthetic fixture but no dimension carries an expected-value assertion -- the vague-AC detector still never matches, dimension 3 never sees an invalid diagram, dimension 4 never sees a fabricated ID, and the only total check is a self-consistency identity, so an inverted dimension still scores 100 for every input
  CA-040 P1 convergence_exempt still has zero occurrences anywhere in bin/tests -- neither consumer, neither mode half, not the legacy null branch, and not the deliberate asymmetry that approve-gate code-audit stays refused under fast-track, so an edit routing approve-gate through the helper opens a gate bypass silently
  CA-042 P2 the missing-baseline vacuous-pass mode is fixed and tested, but check_state_unchanged still discards the command's exit code and output across 49 call sites, no check_refuses_and_leaves_state helper was added, and the four read-only sites still have no output assertion
  CA-049 P2 edm-lint-artifacts and edm-check-grants moved to BASH_SOURCE but edm-check-vocabulary:56, edm-sync-canonical-sections:32, wave4b-smoke.sh:6 and wave6-smoke.sh:714 still derive the root four ways under two names -- and the vocabulary site now sources the shared library off its $0-derived path; _harness.sh still exports no shared root, so three suites also keep a byte-identical bare-mktemp EXIT-only TMP preamble that diverges from wave6/wave7 hygiene
  CA-056 P2 both the grep -qxF pre-flight at :3778 and awk's $0 == h at :3647 are still fence-unaware and first-match-wins, so a pattern doc documenting its own Append Schema inside a fence gets the entry spliced into the fenced example and trips the blocking four-heading contract job
  CA-058 P2 collect_md_files now has -type f, -print0 and an unreadable-file guard, but the class-4 line sets still ride in the environment with a || true consumer, so a large all-mermaid artifact can hit E2BIG and report zero findings indistinguishably from clean
  CA-059 P2 the round number is now printed inside the lock, double round completion is checked inside the lock, and cmd_init takes the lock -- but record-partial-verdict close is still pre-check-then-lock, so two concurrent closes both take the first-closure branch and the close-once invariant is violated silently
  CA-061 P2 record_degraded_check is now idempotent on (check, reason) so degraded_checks no longer grows without bound, but gate-check still routes through rmw_state on every hook invocation for a legacy initiative -- taking the write lock, writing a .bak, and failing on a read-only checkout while its help text still says read-only
  CA-064 P2 an unparseable or zero-byte run.json still defaults to complete: true -- the guard coerces the unknown case to true rather than false -- so edm-compare-eval still compares a partial run against the baseline, exactly what the handshake exists to prevent
  CA-066 P2 the du gate is now scoped to tracked bytes but evals/runs/ still has no retention policy in code or in evals/README.md, so every local invocation adds three claude -p payloads plus stderr logs and nothing prunes
  CA-068 P2 the duplicated Added bullets are deleted but the AC8 row still cites git diff --stat shows zero changes as the proof of PASS, which the same file declares invalid at :75-76 -- and hooks.json:86 has since changed, so the claim is now false on its own terms
  CA-069 P2 the approve-gate usage and the archive re-query refusal are fixed, but the convergence waiver still names mode as the cause, printing standard mode -- skipping code-audit convergence check on the lifecycle-mode trigger, one line above a message that names both fields correctly
  CA-070 P2 none of the three stale contracts was fixed -- :411 still documents tokens.cache_write which nothing writes, :325 still covers 10 of 14 skills omitting verify-runtime/test/test-plan/test-coverage, and :774-775 still says cmd_init writes the running wave when edm-state:1294 writes the literal 1
  CA-071 P2 the digest-pinning header now names the bash:3.2 exception, but the colon-promising-a-list defect survives in the sibling branch -- the lint:file-type-ban evals size-budget failure at :192 ends in a colon and exits without printing the offenders, while the banned-file branch at :173-174 earns its colon
  CA-073 P2 neither half fixed -- --all-lint still prints the unmeasured N_INITIATIVES default of 50 in a harness whose header says no numbers are invented and which CHANGELOG:202 quotes as the AC7 evidence, and the --mermaid-ratio comment still explains the ratio by a short-circuit the mode disables for every file while saying 1.0x against the printed 1.40x budget
  CA-074 P2 die() still has four shapes across eleven scripts with edm-lint-artifacts defaulting to exit 1 among siblings defaulting to 2, edm-validate-prefix still inverts the family exit codes and additionally prints the exit code inside its own message via $*, and neither set -uo site got the comment the remediation asked for
  CA-076 P2 the unjustified git install was dropped from lint:grants and lint:vocabulary and the library-doc count is now computed, but lint:bash-syntax, lint:artifacts and lint:shellcheck still print no terminal job-named verdict where four sibling lint jobs do
  CA-079 P2 51 non-ASCII bytes remain across seven test files while wave6, wave7 and timing.sh are clean, and run-all.sh:50 still prints an em dash to stdout on every pipeline via the blocking test:smoke job, violating on stdout the ASCII rule its own suite asserts for every committed artifact
  CA-080 P2 the False-Alarm-Filter lead-in is now uniform across all eleven lenses, but dead-code and logic still carry a Before reporting preamble and a closing line the other nine lack, in two phrasings that disagree on whether the criteria are conjunctive, and edm-audit-logic:73 still renders the canonical-severity clause as a bulleted field where ten render a bare sentence
  CA-081 P2 unchanged -- e2e's Step-0 exit token is still a bare N/A that is a strict prefix of all five siblings, and a11y's bottom-of-file string still differs from its own Step-0 token while the adjacent line claims they are the same
  CA-084 P2 _now and _ms_between are now guarded by command -v perl but --mermaid-ratio still calls perl -e unconditionally, so the mode still aborts under set -euo pipefail on the perl-less images the fallback exists for
  CA-085 P2 the job-body extractor now resets on a pattern that matches colon-bearing job names, but an absent job still yields an empty body that matches no network pattern and is scored clean, the grep is still only curl/wget/anthropic.com so before_script installs stay invisible, and no positive control was added
  CA-086 P2 unchanged: the comment still claims nothing grants unrestricted shell access and the run cannot reach outside the scratch tree, while :231 grants Bash(jq *) and Bash(edm-state *) under a literal-prefix matcher with --permission-mode acceptEdits and no human in the loop
  CA-087 P2 unchanged: the five UserPromptExpansion hooks still apply no charset filter to $ARGUMENTS, unlike the PreToolUse hook which filters its derived prefixes, and still block expansion with a bare exit 1 and no message when $ARGUMENTS is empty
  CA-088 P2 unchanged (moved to :438/:448): the filename-derived lens_n is still interpolated unescaped into a grep -E pattern, so a run directory containing a file named with a glob metacharacter skews dimension 5 against the wrong row count with no signal
  CA-089 P2 srd.md:2755-2759 now sanctions the shipped tripwire, but T39 AC7 still specifies a script asserting the duplicated blocks are identical (the inverse of edm-check-skill-sync:42-60), its verify command describes exits the script does not have, and epics/05:628 and :101 still forbid building it while run-all.sh:137-144 invokes it
  CA-094 P2 seven independent whole-tree --all lint scans and thirteen whole-tree edm-check-grants runs still execute in one suite with nothing mutating the tree between them; no grants capture was added and the lint capture is still declared below seven of its potential consumers, even though the CA-103 invariant fingerprint that makes collapsing safe has now landed
  CA-095 P2 all eleven lens definitions still cite skills/code-audit/SKILL.md:40 for a mkdir -p that moved from line 45 to line 59 during remediation, so the one duplicated fact drifted a further fourteen lines in eleven places at once; edm-check-grants:13 and :335 remain stale too
  CA-096 P2 the same standalone-checker invocation block still appears twice differing only in script name, variable prefix and label, and the predicted cost has landed: edm-check-vocabulary, the third standalone checker and one of the two in blocking CI jobs, is not invoked by the aggregator at all
  CA-099 P2 the nine CLAUDE.md in-layout assertions are unchanged and still match a bare filename anywhere in a thousand-line file, so moving an artifact out of the layout block while mentioning it once in prose keeps all nine green; _wave7_extract_section exists for exactly this and is not used here
  CA-100 P2 the four-job lint-split loop scores a nonexistent job as compliant because an absent job yields an empty awk block containing no allow_failure, existence, stage and checker-union are still unasserted, and wave7:3402 still prints the split as an unfixed gap while :1015 and :3383 treat it as landed
  CA-101 P2 strip_entities' explicit 1..10 character walk is never tested at either boundary, and the parenthesised and curly label spans have no valid counterpart proving a legal label with a trailing terminator passes -- CARRIED, NOT RE-VERIFIED in round 2 (L4 reported low confidence and did not read the T43 scratch fixtures closely enough to decide)
  CA-102 P2 the alternation count was split into four scoped assertions, but sed -n '69,106p' still pins three assertions to absolute line numbers in a file other tickets edit freely, while _wave7_extract_section written to replace exactly this is used at one site in the whole suite; three drift-prone literal counts still name no source of truth
  CA-127 P2 re-opened from NOTED: the repository-root CLAUDE.md plugin registry entry still reads edm v2.1.0 and omits the /edm:verify-runtime skill T33 shipped, while marketplace.json:35 is 3.1.0 and :45 registers the skill -- no ticket names the file, but tickets/README.md:92's cross-cutting AC covers it and a new user-invocable slash command is user-visible behaviour
  CA-133 P2 command substitution strips the pattern entry's trailing newline and _splice_pattern_file writes it with printf '%s', so multi-entry appends lose the blank line before every ### after the first and the last entry is concatenated onto the line at insert_line -- destroying a ## heading whenever the target section has no blank line or rule before the next section boundary, inside the lock, atomically, with nothing detecting it at write time
  CA-134 P2 write_atomic captures ec=$? directly after "$@" > "$tmp" and after mv under set -e, so it is correct only because all five current call sites sit in errexit-suspended positions; a bare call would abort the process instead of returning, and the one bare call at :1337 runs inside the flock subshell where suspension propagation is implementation-dependent across bash 3.2 and bash 5.x
  CA-135 P2 the CA-001 migrate-schema guard's own comment claims a non-integer schema_version fails the -le check and is reported, but coercing to 0 makes that check false, so a file claiming shape 2 is silently stamped down to 1 -- contradicting the never-lowers-schema_version contract -- and :2002 prints the coerced value rather than the corrupt one
  CA-136 P2 the first two get-coverage jq renderers lack the || true fallback their two siblings carry, so an unparseable state file that passes the [[ -f ]] guard aborts the command under set -e with no message at all because jq's diagnostic is already sent to /dev/null
  CA-137 P2 state_anomalies declares a local found accumulator and assigns it at twelve anomaly sites but never reads it and returns 0 unconditionally -- vestigial from the pre-T05 exit-code contract, and every anomaly class added since has copied the dead assignment forward
  CA-138 P2 a self-test assertion whose condition is byte-identical to the branch-1 assertion 26 lines earlier against the same unchanged output, so it can never fail independently, prints nothing on success, and makes seven increment sites report against a hardcoded /6 denominator that D28 quotes as evidence
  CA-139 P2 score_from_ratio clamps v to >= 0 and then tests (v < 0) two lines later in the same awk BEGIN block with no intervening assignment, so the negative-rounding arm of the ternary is unreachable for every input in the scorer's one shared normalizer
  CA-140 P2 schema_at_least coerces sv through to_int with an explicit default, which always prints a non-empty value, so the -z "$sv" disjunct on the next line can never be true -- residue left by the CA-001 remediation that inserted the coercion above the pre-existing guard
  CA-141 P2 stale-lock reclamation added by the CA-025 fix is not atomic and mis-classifies live holders: the rm -rf between the kill -0 check and the mkdir can delete a lock another contender just took, kill -0 reports EPERM for a live cross-user holder as dead, and both reclaim paths continue without incrementing the retry bound
  CA-142 P2 write_atomic installs a second trap layer inside with_state_lock's mkdir branch -- nesting depth two, which bin/tests/_harness.sh:49-50 documents as unsupported on bash 3.2 -- so a signal during the write leaks the lockdir, and an empty trap -p capture would re-disarm the outer cleanup CA-025 was filed to protect
  CA-143 P2 the lock and write_atomic INT/TERM handlers clean up and then let execution resume, so a Ctrl-C inside the critical section releases the lock and keeps running the read-modify-write unlocked while another process can acquire it, and the trailing rm -rf then removes the other process's lock
  CA-144 P2 an edm-lint-ignore marker on the line before a fence opener consumes the opener via ignore_next's next, so the fenced body is scanned as prose and the fence's closing line is then parsed as an opener, inverting suppression for the remainder of the file; the CA-057 END reconciliation cannot see it because the machine ends balanced
  CA-145 P2 the two new shared helpers count_matches and assert_absent_with_control have no self-test in harness-smoke.sh despite being the remediation vehicles for CA-036 and CA-037 at 21 call sites, and count_matches collapses grep's file-not-found exit 2 into 0, which is the passing value for every expect-zero caller
  CA-146 P2 the aggregator's own result accounting -- rewritten by CA-016's remediation with three new branches -- is covered by no test at all; run-all.sh is not a *-smoke.sh so it never self-discovers, harness-smoke.sh has no case for it, and wave7:339 only greps its text, yet every Verify: run-all.sh AC rests on it
  CA-147 P2 timing.sh's seven measurement modes are covered by a single grep for the token generate-fixture plus an executable-bit check, so a stub echoing that one word passes both; the script produces the committed latency budgets in CHANGELOG.md and CLAUDE.md and is exercised nowhere else
  CA-148 P2 no test asserts that .gitignore covers the lock and temp names edm-state derives from lockbase, which is why the same unmatched-pattern defect shipped in EDMV2 and again in EDMV3 round 1
  CA-149 P2 three ignore patterns are anchored to the literal SRD/ prefix while srd_root relocation is documented and supported, so a relocated tree re-exposes the lock files and the findings-ledger and HANDOFF staging files as untracked
  CA-150 P2 canonical-sections.md.tmp.XXXXXX is the only staging path in the plugin no .gitignore glob matches -- the prescribed plugins/edm/docs/*.tmp.* line was never added -- and the trap omits HUP
  CA-151 P2 the scorer unconditionally writes scores.json into whatever directory it is given and the fixture README documents pointing it at the tracked bin/tests/fixtures/code-audit/, which already deposited an untracked file there once
  CA-152 P2 the post-D32 pricing walkthrough claims eight arms in this order and places the unknown sentinel after all six version arms, but edm-state:397 puts unknown between haiku-4-6 and sonnet-4-7 -- a false order claim in the one passage whose whole subject is why arm order matters and which a contributor adding the EDMV4 Sonnet 5 row would consult
  CA-153 P2 the new shared library sourced by three shipped binaries carries a shebang and no documentation -- the de-indent rationale at :28 was lost in the extraction, report_violation's two incompatible signatures have different field order not just arity and are undocumented, and the four emitted classes and the violations/VIOLATIONS counter convention are stated nowhere
  CA-154 P2 Mirrored verbatim in edm-lint-artifacts, and its twin at edm-lint-artifacts:5, names one of eleven sites that now carry the sentinel extractor after the CA-005 sweep, and the family is not verbatim -- two awk forms differ on whether the leading # is stripped, so --help renders differently across the family
  CA-155 P2 the shared report_violation probes for two caller-specific counter globals (violations, then VIOLATIONS) instead of resolving the naming divergence, so a consumer that names its counter anything else prints findings, counts none and exits 0 on a dirty tree with no diagnostic, and one that declares both increments only the lowercase one
  CA-156 P2 ignored_line_set survives as a byte-identical four-line hand-copy in edm-check-grants and edm-check-vocabulary -- the two files the shared library was created to de-duplicate -- and is derived a third way inline in edm-lint-artifacts, so build_line_classes' tab-separated record shape now has three independent parsers outside the library
  CA-157 P1 the arithmetic-context injection class is still live on a second input channel: phase-start's unvalidated <phase-num> argument reaches [[ $((gated_phase + 1)) -eq "$phase" ]] via :1545, giving arbitrary execution to any caller holding only the Bash(edm-state *) prefix grant -- including the committed eval driver's own allow-list under --permission-mode acceptEdits with no human in the loop
  CA-158 P1 the perl-less _now fallback added by the CA-084 remediation adds rand() to systime(), so on the perl-free images the fallback exists for every measured duration carries up to one second of random error and can be negative, in a harness whose header asserts no numbers are invented and whose output CHANGELOG.md quotes as the T67 budget evidence
  CA-159 P2 write_atomic and with_state_lock interpolate a filesystem path into a single-quoted trap body, so an apostrophe in the install or project path makes the cleanup a syntax error at signal time -- leaking a tracked-directory temp file and a stale lock -- and a crafted path is trap-body injection; SRD_ROOT is not charset-validated the way EDM_PRODUCT now is
  CA-160 P2 HUMAN_HOURLY_RATE_USD is spliced into jq program text rather than passed with --arg (every sibling use passes it as awk -v data), and neither it nor EDM_TOKEN_READ_LINE_CAP, which goes straight to tail -n, is validated at startup, so a misconfigured install fails mid-write with a raw tool diagnostic
  CA-161 P2 eleven blocking jobs each resolve their toolchain from a mutable Alpine package index at run time on top of placeholder-digest images, so neither the image layer nor the package layer is actually pinned despite the header presenting pinning as the reproducibility story, and a silently-changed shellcheck or jq changes what the blocking lint jobs accept
  CA-162 P2 lint:shellcheck covers only plugins/edm/bin/* -- not bin/tests/*.sh, which lint:bash-syntax does cover, and not plugins/edm/evals/*.sh, which nothing lints -- which is the same blind spot that let the CA-014 mktemp template and CA-088's unescaped interpolation ship
  CA-163 P2 two round-1 AC reworks landed with no change-control record -- D19 still names only T61 AC13 and T01 AC9 though six ACs were amended, and D23 still never names T23 though AC13 was rewritten -- against the pack's own rule at tickets/README.md:64-65 that an unverifiable AC is reworked through gate change control
  CA-164 P1 the lens launch template hands the lens the findings-ledger schema (id CA-NNN, lenses array, component, raised_round) while all eleven agent definitions and all eleven committed fixtures declare the lens-stage schema (id null, lens, file, line), and the skill is the operative instruction at spawn time -- introduced by the CA-020 fix and live again this round, with the lenses following the prompt rather than their own contract
  CA-165 P2 dimension 5 counts prose rows matching a leading L{N}-NNN local ID which only the hand-authored fixture emits; every lens agent's Output Format template shows a plain integer row, so the metric scores 100 against its own fixture and 0 against any real pass directory
  CA-166 P2 steps 6 and 7 brief every lens from findings-ledger.md, which :18 and :48 call the canonical persistent ledger, while :70, :233 and :247 in the same file declare findings-ledger.jsonl authoritative and the markdown a render of it, so prior-round context is read from the derived copy and a round interrupted before step 9a briefs every lens off a stale render
  CA-167 P2 the only user-facing MCP-unavailable message routes the operator to CLAUDE.md -> 'Atlassian MCP setup', a section that exists nowhere in plugins/edm/CLAUDE.md; the real guidance is the jira_mcp_namespace row at CLAUDE.md:866 and push-jira/SKILL.md:219
  CA-168 P2 the only pattern-library document with no loader and no writer -- its four siblings are each Read by a named agent or skill and each mapped by an update-patterns audit type at edm-state:3740-3743, while edm-test-coverage-auditor.md and test-coverage/SKILL.md never reference it, so it is read-orphaned and write-orphaned at once
  CA-182 P0 cmd_approve_gate's code-audit convergence precheck only runs when schema_version >= 2 -- an initiative with schema_version still at 1 (the literal cmd_init writes, per CA-070c, and never auto-migrated) skips cmd_audit_converged entirely and falls to the wave-A permissive branch, which records the approval unconditionally. Live-reproduced on EDMV3 itself: 91 blocking findings open, audit-converged exits 1, yet approve-gate code-audit succeeded and set code_audit_converged=true until an operator caught it, migrated schema_version to 2, and manually reverted the field (no cmd_set path exists for it by design). Any initiative that never ran migrate-schema -- which nothing prompts a user to do -- has an always-bypassable code-audit gate.

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