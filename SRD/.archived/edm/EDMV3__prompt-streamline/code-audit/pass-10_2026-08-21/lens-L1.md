# Lens L1: Logic, Correctness & Completeness -- Round 10 (pass-10, 2026-08-21)

Scope swept: `plugins/edm/bin/*` (`edm-state`, `edm-lint-artifacts`, `edm-lint-staged-artifacts`, `edm-check-grants`, `edm-compare-eval`, `_edm-cli-lib.sh`, `_edm-lint-lib.sh`), `plugins/edm/bin/tests/*.sh`, `plugins/edm/hooks/hooks.json`, repository-root `.gitlab-ci.yml`, `plugins/edm/skills/implement/SKILL.md`, `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/agents/*.md`, `plugins/edm/evals/**`, `plugins/edm/CLAUDE.md`, `plugins/edm/CHANGELOG.md`.

Tooling caveat (CA-130, 10th consecutive round): this lens ran with **no `Bash` and no `Write`**. Nothing was executed; every claim below is derived from reading source. Both halves are returned in the agent message per the fallback clause.

---

## Priority 1 -- verdicts on every open ledger entry naming L1

Open L1-tagged entries in `findings-ledger.jsonl`: **CA-401, CA-453, CA-473, CA-474, CA-478, CA-491**. Each re-derived against the current tree with file:line evidence; none taken on the commit message's word. (`CA-416` and `CA-424`, also named in the round brief, are not L1-tagged and are not adjudicated here.)

| ID | Verdict | Evidence in the current tree |
|---|---|---|
| **CA-473** (P1, L1+L3) | **FIXED -- recommend close** | Namespaces are now disjoint at all four writers. `plugins/edm/hooks/hooks.json:117` step 5 writes `qc/qc-shard-impl-{NN}.md` and adds an explicit "NEVER write a bare `qc/qc-shard-{NN}.md` or any `qc-shard-pass-*.md` name either (CA-473)" clause. `plugins/edm/skills/implement/SKILL.md:81-83` documents the `impl-` prefix, `:84-85` the `pass-` prefix keyed on shard ordinal, `:86-91` states the MUST-NOT-overlap rule and names the exact collision (threshold shard 1 vs. the implementer whose range starts at T01). Both pseudo-code branches now agree: `:106` `qc-shard-pass-01.md` (small initiative -- no longer the byte-identical lowest-ticket key) and `:110` `qc-shard-pass-{i+1:02d}.md`. The merge glob is widened at `:92-94` and `:114` to both prefixes. Durability pin landed: `plugins/edm/bin/tests/wave7-smoke.sh:8688-8731`, including a token-disjointness assertion (`:8730`) and a both-branches-agree assertion (`:8726`). `plugins/edm/bin/edm-state:2552` records that the anomaly scanner is deliberately prefix-agnostic so it matches both namespaces. |
| **CA-474** (P1, L8+L1) | **FIXED -- recommend close** | `read -r -d ''` is gone from the entire file. `.gitlab-ci.yml:312` derives `EXPECTED_COUNT` from `jq ... | length`; `:316-321` rejects a non-numeric count up front (a hole the original prescription did not name); `:322-342` is a POSIX `while [ "$IDX" -lt "$EXPECTED_COUNT" ]` index loop with `jq -r --argjson n` writing each `.command` to its own temp file. The job header at `:277` now states "The whole script body below is POSIX-sh-safe for that same reason -- no `read -d`, no `[[`, no arrays, no herestrings (CA-474)", so the file no longer asserts one thing and does another. The cross-check message at `:344` was retargeted to "jq index/loop-bound mismatch" rather than the misdiagnosing splitting-regression text. |
| **CA-478** (P2, L1) | **FIXED -- recommend close** | `plugins/edm/bin/edm-state:4548` is now `while IFS= read -r _lens || [[ -n "$_lens" ]]; do`, and `:4549` strips a trailing carriage return (`_lens="${_lens%$'\r'}"`) before the `^L[0-9]+$` test at `:4550`, closing the secondary CRLF trigger as well. Rationale recorded at `:4544-4547`. Both classes are pinned: `wave6-smoke.sh:918-933` (manifest with no trailing newline still names `L2` and still downgrades to partial) and `:935-948` (CRLF manifest still fires the gate). |
| **CA-401** (P2, L4+L1) | **STILL OPEN** -- cited, not re-filed | Bare `grep -c` captures under `set -euo pipefail` with no `|| true` and not routed through `count_matches`: `wave6-smoke.sh:290`, `:1128`, `:1145`, `:3512`, `:3519`, `:3531`; `wave7-smoke.sh:3778`, `:3785`, `:3853`, `:4873`, `:4877`. Line numbers shifted again from round 9's citation (`:290, :1057, :1074, :3441, :3448, :3460`); the sites are the same class. `wave7-smoke.sh:1301` shows the guard being applied correctly at one CA-401(b) site, which is what makes the eleven remaining ones a miss rather than a convention. |
| **CA-453** (P2, L1) | **STILL OPEN** -- cited, not re-filed | Verified three ways, unchanged from round 9. (a) A grep for the rendered string `Gates approved` across `plugins/edm/bin/tests/` returns exactly one hit and it is a comment (`wave6-smoke.sh:649`), not an assertion. (b) `required_gate_count` -- the denominator both findings are about, assigned at `edm-state:5602-5621` and rendered at `:5958` -- appears in **no** test file. (c) The reconciling note emitted at `edm-state:5786` ("N approval event(s) recorded above for M distinct gate(s)") has no assertion anywhere. None of the four prescribed cases landed; `wave4a-smoke.sh:305-310` counts `.gates_approved` entries in *state*, not the rendered HANDOFF line, so it cannot substitute. |
| **CA-491** (P2, L4+L1) | **STILL OPEN** -- cited, not re-filed | A grep for `missing-task-grant` (and for `CA-441`) across `plugins/edm/bin/tests/` returns **zero** hits. The only must-fail grants case is `wave7-smoke.sh:365-397` (`t03_ac6_case`), which strips `AskUserQuestion` from a scratch copy of `skills/plan/SKILL.md` and asserts only `missing-askuserquestion-grant` (`:392`). The CA-441 rule at `edm-check-grants:506-517` still has no negative case, and its trigger at `:515` is false on the live tree, so `mark_and_maybe_report` is never reached -- the family of "exits 0 against the live tree" assertions passes identically whether the rule works or does not exist. Both folded-in known limits are also unchanged: `:511` derives `task_ln` from a whole-file grep while `needs_task` comes from `$body`, and `:509`'s spawn alternative still requires the verb and the `edm-` prefix on one line. |

---

## Findings (L1: Logic, Correctness & Completeness)

### L1-001 [P2] The new `qc` finding extractor keys on the `**Finding**:` label, but the authoritative QC finding-line format -- the one the agent's own `## Finding Format` section and the implement skill both prescribe -- carries no such label, so a conforming `qc-summary.md` extracts zero titles forever

**File**: `plugins/edm/bin/edm-state:5230`

```awk
NF >= 2 && $0 ~ /^\*\*Finding\*\*:/ {
```

The CA-476 remediation replaced the blanket `grep '^### '` with a per-audit-type shape rule, which is the right structure. The `qc` arm's stated authority is `agents/edm-qc-auditor.md Sec."Output Format"` (comment at `edm-state:5184-5187`), and that section's examples at `agents/edm-qc-auditor.md:114` and `:120` do carry the `**Finding**: ` label. But the **same agent file** defines the canonical finding line one section earlier, at `agents/edm-qc-auditor.md:59-63`, with no label at all:

```
[SEVERITY] {PREFIX}-T{NN} | path/to/file.py:line | AC#{N}: {criterion text} | {what's wrong}
```

and `skills/implement/SKILL.md:122-126` -- the surface that *owns* the merge step producing `qc/qc-summary.md` (`SKILL.md:92-94`) -- restates that unlabelled form verbatim as "Finding format", for both the FAIL and the PARTIAL shape. Two documented shapes, one extractor, and the extractor's regex is anchored (`^\*\*Finding\*\*:`) so it matches exactly one of them.

Consequence: a shard auditor that follows the `## Finding Format` spec (the more prominent of the two, and the only one the invoking skill repeats) produces a `qc-summary.md` from which `pattern_extract_titles qc` extracts **nothing**. `pattern_extraction_status_for` then returns `no-recognized-findings` (`edm-state:5256-5257`), the arm warns and records `extracted_titles: 0` -- so CA-476's loudness fix means this is no longer *silent*, which is exactly why it is P2 and not P1. But the qc arm of the pattern library still contributes nothing, permanently, and the warning at `:5511` tells the operator "either the report does not follow its own documented format, or it genuinely records no findings" when in fact the report may be following its own documented format precisely.

False Alarm Filter: fails all three. (1) Nothing in `docs/audit-patterns/README.md` Sec."Append Schema" sanctions matching only the labelled variant. (2) The code comment at `:5184-5185` asserts a single documented form and does not acknowledge the competing one. (3) The sibling `srd` arm's authority (`agents/edm-srd-auditor.md:71-75`) is a *single* unambiguous format, so this is not a project-wide pattern of picking one of several.

**Concrete fix** -- accept both shapes with one alternation, and reconcile the two documents in the same commit:

```awk
NF >= 2 && ($0 ~ /^\*\*Finding\*\*:/ || $0 ~ /^\[[A-Za-z0-9]+\][ \t]+[A-Za-z0-9_-]+-T[0-9]+[ \t]*\|/) {
```

Then either (a) delete the unlabelled block at `agents/edm-qc-auditor.md:59-63` and `skills/implement/SKILL.md:122-126` in favour of the labelled `Output Format` rendering, or (b) add the `**Finding**: ` prefix to both, so exactly one shape is documented. Extend the CA-476 qc case at `wave7-smoke.sh:4150-4193` with a fixture line in the *unlabelled* shape and assert it is extracted, plus a positive control.

---

### L1-002 [P2] `pattern_extract_titles` hand-rolls fence detection that only recognises column-0 fences, while its own comment claims parity with the shared classifier that handles indented fences -- an example finding inside an indented fence is harvested as a real pattern

**File**: `plugins/edm/bin/edm-state:5205` (and the identical inline trackers at `:5216` and `:5228`)

```awk
/^```/ { infence = 1 - infence; next }
infence { next }
```

The function's header comment asserts:

> Fence-aware throughout, for the same reason `pattern_insert_line_for` is (CA-056): a report that quotes an example finding inside a fenced code block is documentation, not a finding. -- `edm-state:5197-5198`

That parity does not hold. `pattern_insert_line_for` (`:5300`) and `_cmd_update_patterns_body` (`:5363`) resolve fences through `ignored_line_set` / `is_ignored_line` from `_edm-lint-lib.sh`, whose documented contract explicitly covers indented fences -- `edm-lint-artifacts:53-54`: "Lines inside ``` code fences are also ignored automatically, **including fences indented inside a numbered step or list item**." The three awk arms added by the CA-476 fix re-implement fence tracking from scratch with a `^`-anchored pattern, so a fence opened as part of a numbered remediation step (` ```markdown` indented under `1.`) never toggles `infence`.

Concrete harm, and it is the exact harm CA-476 was filed for: a `REMEDIATION.md` that documents the report format by quoting an example heading such as `### CA-NNN (P1, lens L1): ...` inside an *indented* fence has that example extracted as a genuine finding and appended to `docs/audit-patterns/code-audit.md` as a `status: pending-review` entry -- a shipped plugin asset thirteen prompt surfaces read as accumulated wisdom. This methodology's own reports quote their own formats constantly (`skills/code-audit/SKILL.md` and every agent definition in `agents/` carry fenced format templates), and indented fences inside numbered steps are the plugin's normal prose style.

Secondary, same root cause: the three trackers are three copies of one rule, so a fix to one silently leaves the other two behind -- the CA-472/CA-512 duplication class at a new site.

False Alarm Filter: fails clause 2 outright -- the comment does not explain the divergence, it *denies* it. Fails clause 3 -- the shared classifier is used at every other fence-sensitive site in this same file.

**Concrete fix** -- one shared helper, not three copies. Either (a) pre-filter the report through the existing classifier and feed awk only the non-ignored line numbers (the `MERMAID_SCAN_FILE` / `getline` idiom `edm-lint-artifacts:196-229` already uses), or (b) if a self-contained awk arm is preferred for the no-`_edm-lint-lib.sh` case, change all three trackers to the indent-tolerant form and say in the comment that this is a deliberate reduced-fidelity copy:

```awk
/^[ \t]*```/ { infence = 1 - infence; next }
```

Add a wave7 case to the CA-476 block seeding a `### CA-999 ...` heading inside a fence indented under a numbered step and asserting it is **not** extracted, with a positive control at column 0.

---

### L1-003 [P2] The `code` arm's post-ID delimiter class excludes `/` and `-`, so a compound-ID finding heading -- the plugin's own dominant compound form, `G{N}/CA-{N}` -- is not recognised as a finding

**File**: `plugins/edm/bin/edm-state:5210`

```awk
if (t ~ /^(CA-[0-9]+|G[0-9]+)([ \t:(]|$)/) print t
```

The rule requires the character immediately after the ID to be a space, tab, colon, open-paren, or end-of-line. The plugin's compound in-round/ledger ID form is written with a slash everywhere it appears -- `G21/CA-233` (`.gitlab-ci.yml:109`, `:245`), `G16/CA-355` (`edm-state:5392`, `:5466`), `G13/CA-391` (`wave6-smoke.sh:646`), `G11/CA-389` (`edm-state:5604`), `G12/CA-390` (`:5775`), `G39/CA-270` (`wave7-smoke.sh:411`), `G4/CA-335` (`edm-state:5571`). A heading of the shape `### G21/CA-233 -- the exclusion arm diverged` fails the test on the `/`, and `### CA-233-followup ...` fails on the `-`.

Effect: a genuine finding heading is dropped from the harvest. Because CA-476's loudness fix only reports `no-recognized-findings` when the count reaches **zero**, a report mixing recognised and compound-ID headings reports `extraction_status: ok` with a silently short count -- the one state where `new_findings: 0` is documented at `:5249-5250` to mean "clean round". That makes this the residual of CA-476 in the direction its own fix does not cover.

Confidence is **low** on live incidence: I could not execute anything this round, so I did not confirm that a shipped `REMEDIATION.md` heading uses the compound form (the wave7 fixtures at `:4024` and `:4058-4060` exercise the bare `CA-NNN (` and bare `G{N}` forms only). The regex gap itself is read directly off `:5210` and is not in question.

**Concrete fix** -- invert the test to "not an ID character" rather than enumerating delimiters, so no future punctuation convention can silently fall out:

```awk
if (t ~ /^(CA-[0-9]+|G[0-9]+)([^0-9A-Za-z]|$)/) print t
```

and add a fixture heading in the `G{N}/CA-{N}` compound form to the CA-476 code-arm case at `wave7-smoke.sh:4024-4088`, asserting it is extracted.

---

### L1-004 [P2] `lint:hooks-shell` writes the four-byte string `null` to its temp file for a command-type hook whose `.command` key is absent, and both checks pass it -- the blocking gate over the plugin's most privileged shell prints OK for a hook it never checked

**File**: `.gitlab-ci.yml:328`

```sh
jq -r --argjson n "$JQ_IDX" '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command")][$n].command' plugins/edm/hooks/hooks.json > "$cmdfile"
```

`select(.type=="command")` filters on the *type* tag; nothing requires the object to carry a `.command`. For an entry with `{"type":"command"}` and no `command` key (or an explicit `null`), `jq -r` emits the literal text `null`. `bash -n` accepts `null` (a well-formed single-word command), and `shellcheck --shell=sh` accepts it too. So `:330` prints `OK: bash -n hook #N`, `:337` prints `OK: shellcheck hook #N`, `COUNT` reaches `EXPECTED_COUNT` by construction, and `:351` prints `lint:hooks-shell: OK -- N command-type hook(s) clean`.

This is the exact failure direction the job exists to prevent, one level up: CA-437 was about a command string being *split* so that malformedness escaped detection; this is a command string being *absent* so that malformedness escapes detection. The job is `needs: []`, no `allow_failure`, and per its own header at `:265-268` it covers "the most privileged shell in the plugin (it runs automatically with no permission prompt on every commit)". `edm-check-grants` parses the same file but reads `"prompt":` entries (`:466`), not `.command`, so no sibling check backstops this.

Not cleared by the filters: the header's stated contract at `:270` is "Extracts every command-type hook's `.command` string via jq and runs both checks over each" -- an entry with no `.command` string is a case that contract does not cover and the code does not detect. Confidence **medium**: the gap is certain from reading; reachability requires a malformed `hooks.json`, which is precisely the input class a lint job is for.

**Concrete fix** -- validate the extraction instead of trusting it. Tighten the selector and fail on a null:

```sh
EXPECTED_COUNT="$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command")] | length' plugins/edm/hooks/hooks.json)"
WELLFORMED="$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | select(.command | type=="string" and length > 0)] | length' plugins/edm/hooks/hooks.json)"
if [ "$WELLFORMED" -ne "$EXPECTED_COUNT" ]; then
  echo "lint:hooks-shell: FAILED -- ${EXPECTED_COUNT} command-type hook(s) declared but only ${WELLFORMED} carry a non-empty string .command"
  exit 1
fi
```

Pin it with a wave7 case that copies `hooks.json` to scratch, deletes one `.command` key, and asserts the job body fails -- there is no assertion today that would turn red.

---

## Noted / Not Actionable

- **CA-401 -- STILL OPEN**, eleven unguarded bare `grep -c` captures under `set -euo pipefail`: `wave6-smoke.sh:290, :1128, :1145, :3512, :3519, :3531`; `wave7-smoke.sh:3778, :3785, :3853, :4873, :4877`. Confirmed at shifted line numbers. Cited, not re-filed.
- **CA-453 -- STILL OPEN**, zero of four prescribed assertions landed: `Gates approved` has one hit in `bin/tests/` and it is a comment (`wave6-smoke.sh:649`); `required_gate_count` (`edm-state:5602`, rendered `:5958`) and the reconciling note (`edm-state:5786`) appear in no test file. Cited, not re-filed.
- **CA-491 -- STILL OPEN**, `missing-task-grant` and `CA-441` both return zero hits across `bin/tests/`; the only must-fail grants case (`wave7-smoke.sh:365-397`) exercises `AskUserQuestion` only. Cited, not re-filed.
- **CA-490 (L2) -- STILL OPEN**, cross-lens confirmation only, not L1's to file: `edm-compare-eval:61-65`'s baseline-existence `exit 3` still precedes candidate JSON validation (`:67`) and refusal condition 3 (`:70-78`), which is the reorder CA-490 prescribed. With no `evals/baseline/scores.json` in the tree, the `complete: false` handshake remains unreachable from `.gitlab-ci.yml`'s one-argument call site.
- **CA-479 (L3) -- STILL OPEN**, adjacent to my CA-478 verdict and worth recording as unfixed-in-the-same-function: `edm-state:4537-4540` still walks the `pass-${round_num}_*` glob and silently keeps the last match with no ambiguity diagnostic. Not L1's finding.
- **`.gitlab-ci.yml:343`'s `COUNT` vs `EXPECTED_COUNT` cross-check is now a tautology** -- `COUNT` is incremented in lockstep with `IDX` at `:325-326` before any work, so the condition can never be true. Filter 2: the comment at `:310-311` states this deliberately ("The loop bound IS jq's own command-hook total, which makes the cross-check below structural rather than post-hoc"). Retaining it as a cheap invariant is defensible; the real residue is L1-004 above.
- **CA-114 re-verified NOTED**: `pattern_target_heading_for` (`edm-state:5265-5270`) still ignores its argument and always returns `PATTERN_DEFAULT_TARGET_HEADING`, documented at `:5118-5125` as the intentional extension point contractually coupled to adding a README mapping row. Unchanged by the CA-476 rewrite.
- **CA-289 re-verified NOTED**: `edm-compare-eval:50-53` accepts `-h|--help` but not the bare `help` token that `edm-lint-staged-artifacts:32` and its siblings accept. Recorded do-not-re-file (two lenses saw it, neither claimed it).
- **CA-113 / CA-117 / CA-118 / CA-122 re-verified NOTED**, all unchanged and all still covered by their recorded rationales (`vocabulary-allowlist.txt` carve-out; the shellcheck-disabled `set -- $list` in `edm-check-grants:185`; `edm-init`'s unqualified `git rev-parse --verify`; `_edm-lint-lib.sh`'s in-fence `edm-lint-ignore-end`).
- **`edm-lint-staged-artifacts:58`'s `[ -n "$x" ] && a="$(...)" || a="$x"` chain re-verified correct** for all four input combinations. An assignment whose command substitution fails inherits that non-zero status, so the `||` arm fires exactly when `cd` fails; empty `repo_root` short-circuits to the same arm. Not a bug.
- **`edm-lint-artifacts:137`'s first-stage single-body trap** still cleans up and resumes on INT/TERM/HUP rather than exiting with a signal-shaped code. Filter 2 (deliberately transitional, one `mktemp` wide, purpose stated at `:134-136`); already filed by L3/L7 as CA-482.
- **`edm-state:5502`'s `extracted_count` capture re-verified safe**: the `|| true` sits inside the command substitution, so `grep -c '.'`'s exit 1 on zero matches yields stdout `0` and status 0 under `pipefail`. Correct as written.
- **No unresolved `TODO` / `FIXME` / `HACK` / `XXX` / `NotImplementedError` / stub return anywhere in scope.** Case-insensitive sweep of `bin/`, `bin/tests/`, `evals/`, `hooks/`, `skills/`, `agents/`, `docs/`, `.gitlab-ci.yml`: every hit is prose about placeholder *pricing* (`CLAUDE.md:505-521`), a `TodoWrite`/`TodoRead` tool grant in frontmatter, the `evals/vague-ac-patterns.txt:29` detection token, an anti-stub *instruction* (`skills/implement/SKILL.md:67`, `:209`; `agents/edm-implementer.md:46-47`), a documented placeholder-name expansion (`edm-check-grants:351`), the honest absent-baseline record (`evals/baseline/README.md:7`), or a fixture's deliberate comment content (`evals/fixtures/tiny-svc/src/worker/processor.js:18`). Zero live markers, zero bare `pass`/`:` where logic belongs, zero always-same-literal returns outside the documented `pattern_target_heading_for` extension point (CA-114).
- **CA-130 (no `Bash`, no `Write` in the delivered lens tool set)** -- reproduced for the 10th consecutive round. Remains NOTED per its recorded do-not-re-file disposition; report delivered in the agent message per the fallback clause.
