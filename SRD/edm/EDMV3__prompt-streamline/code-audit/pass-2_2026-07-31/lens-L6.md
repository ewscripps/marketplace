# Code Audit Lens L6: Documentation Accuracy

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Method**: static read of the current tree. No Bash at runtime, so no command was executed and no
  `git diff` was taken; every claim below is a direct read of the file at the cited line. Provenance
  ("changed by the remediation commits") is inferred from content, not from history.
- **Severity source**: graded against `plugins/edm/CLAUDE.md:215-220`, the canonical scale, **not**
  against `agents/edm-audit-synthesizer.md:87-90`. See CA-018 below -- that file is still a lossy
  restatement, so grading against it would have been grading against a divergent copy.

## Round-1 L6 verification summary

| ID | R1 sev | Verdict now | Evidence |
|---|---|---|---|
| CA-005 (L6 half) | P1 | **FIXED** | Sentinels now bracket the whole header in every offender |
| CA-011 (L6 half) | P1 | **FIXED** | Both the help contract and the hook message now describe real behaviour |
| CA-012 | P1 | **FIXED** (residual -> new P2) | Section rewritten to the post-D32 code; one order claim still wrong |
| CA-017 | P1 | **PARTIAL -- still open at P2** | Budget claim and self-contradiction gone; undercount survives, now 2-of-4 |
| CA-031 | P1 | **FIXED in both places** | 2700 / 15 at `:74-75` **and** `:233-234` |
| CA-044 | P1 | **FIXED (re-verified)** | All three interpolations present |
| CA-068 | P2 | **PARTIAL -- still open** | Duplicate bullets deleted; AC8 row untouched |
| CA-069 | P2 | **PARTIAL -- still open** | 2 of 3 messages fixed; the convergence waiver is not |
| CA-070 | P2 | **STILL OPEN -- all three halves** | Nothing in this finding was applied |
| CA-071 | P2 | **PARTIAL -- still open** | Header fixed; the colon-with-no-list moved, not fixed |
| CA-072 | P2 | **FIXED** | Only one comment now claims the 39,872 ms figure |
| CA-073 | P2 | **STILL OPEN -- both halves** | Neither the count nor the short-circuit comment changed |
| CA-018 (L10, verified on request) | P1 | **PARTIAL -- legacy scale gone, restatement remains** | See below |
| CA-105 / CA-126 / CA-127 | NOTED | **Still NOTED** | See "Noted / Not Actionable" |

---

## Findings (L6: Documentation Accuracy)

### CA-018 (P2, re-graded; L10's ID, verified here on request): the synthesizer no longer carries the legacy scale, but still restates an abbreviated one immediately after forbidding restatement

**Site**: `plugins/edm/agents/edm-audit-synthesizer.md:85-90`; identical shape at
`plugins/edm/agents/edm-srd-auditor.md:65-70`. Canonical at `plugins/edm/CLAUDE.md:215-220`.

**The serious half is fixed.** The abolished legacy P1/P2/P3 definitions ("operational friction",
"defensive improvements") are gone from `edm-audit-synthesizer.md`. `grep` across
`plugins/edm/agents` and `plugins/edm/skills` returns those strings only inside CLAUDE.md's and
`docs/canonical-sections.md`'s explicit backward-compatibility mapping, which is where they belong.
`skills/code-audit/SKILL.md:252` and `skills/audit-srd/SKILL.md:81` now carry a pure by-name
reference with no table at all -- exactly the prescribed fix.

**What survives.** Two files replaced the table with a four-bullet paraphrase, and the paraphrase is
lossy in the same direction in both:

| Level | `CLAUDE.md:217-220` (canonical) | `edm-audit-synthesizer.md:87-90` and `edm-srd-auditor.md:67-70` |
|---|---|---|
| P0 | Critical -- blocks implementation, security/legal issue, production failure, **or architecturally wrong** | Critical -- blocks implementation, security/legal, production failure |
| P1 | Significant -- material gap, factual error, **missing requirement, or behavior that must be corrected before shipping** | Significant -- material gap, factual error |
| P2 | Minor -- polish, edge-case, improvement, **or nice-to-have** | Minor -- polish, edge-case, improvement |

The prescribed fix was explicit: "If a summary must remain in the synthesizer, copy CLAUDE.md's
Definition column byte-for-byte." It was not copied byte-for-byte. Worse, the sentence introducing
the bullets is `Do not restate or adapt a local scale.` -- and the next four lines are a restated,
adapted local scale. An agent that follows the instruction ignores the bullets; an agent that reads
the bullets has been handed an adapted scale in which "missing requirement" and "architecturally
wrong" do not appear. A lens reporting a canonical P1 "missing requirement" still matches no row.

Re-graded P1 -> P2 because the failure mode changed class: an *omission* that a reader resolves by
following the by-name pointer, not the *inversion* (legacy definitions under canonical labels) that
round 1 found, which produced an actively wrong answer with no signal that it was wrong.

**Fix**: delete lines `87-90` in `edm-audit-synthesizer.md` and `67-70` in `edm-srd-auditor.md`,
keeping only the by-name reference and the `docs/canonical-sections.md` plugin-relative fallback --
matching what `skills/code-audit/SKILL.md:252` and `skills/audit-srd/SKILL.md:81` already do. If a
summary is judged necessary, paste the Definition column verbatim and add a smoke assertion that the
pasted text is a substring of CLAUDE.md's, so it cannot drift again.

**Disclosure**: `agents/edm-audit-synthesizer.md` defines the agent that will assign this round's
ledger severities. This round's severities were assigned from `CLAUDE.md:215-220`.

---

### CA-070 (P2, STILL OPEN -- all three halves, none applied): three stale `CLAUDE.md` contracts

Nothing in this finding reached the file. Each half re-verified against the current code:

**(a) `plugins/edm/CLAUDE.md:411` -- a token field nothing writes.** The line still reads:

```
- `tokens.{input, output, cache_read, cache_write}` -- raw counts
```

`bin/edm-state:1705` (the `phase-complete` writer) writes
`{input, output, cache_read, cache_write_5m, cache_write_1h}`; `:3135` (`audit-round-complete`)
writes the same five; the zero-sentinel at `:279` and `:349` and the extractor at `:314-315`,
`:344-345` all use the split names. There is no `cache_write` key anywhere in the codebase. The same
CLAUDE.md file contradicts itself 56 lines later at `:467` ("`cache_write_1h` is usually the
dominant figure") and the CHANGELOG records the rename at `:826`. A `jq '.phase_durations[].tokens.cache_write'`
written from this line returns `null` on every state file.

**(b) `plugins/edm/CLAUDE.md:325` -- the skills inventory covers 10 of 14.** The line names eight
opus skills and two sonnet skills. On disk there are 14 `skills/*/SKILL.md`. Reading their
frontmatter: `test` is `opus`/`max` and `test-plan` is `opus`/`high` -- both absent from the "are all
on `opus`" list, so that list is 8 of the 10 opus skills. `verify-runtime` (`sonnet`/`high`) and
`test-coverage` (`sonnet`/`high`) are absent from the sonnet pairing, which reads as exhaustive and
is 2 of 4. `verify-runtime` is the mandatory Phase 6 closure step (`CHANGELOG.md:456`,
`README.md:119`), so the one skill whose omission matters most is the one omitted. Secondary: the
effort sentence ("The two writers run at `effort: high`; planning, audits, and QC run at
`effort: max`") accounts for no bucket containing `skills/implement/`, which is `effort: max`, and
there is no QC *skill* at all -- QC is an agent.

**(c) `plugins/edm/CLAUDE.md:774-775` -- the `schema_version` contract states behaviour the code does
not have.** Still reads "written once by `cmd_init` for the wave the running plugin version belongs
to". `_cmd_init_render` at `bin/edm-state:1294` writes the literal `schema_version: 1`, with no
reference to any plugin version. The running plugin is `3.1.0`
(`plugins/edm/.claude-plugin/plugin.json:4`), and wave-B checks require `>= 2`
(`bin/edm-state:1477`, `:1661`, `:2172`). So a brand-new initiative created today by 3.1.0 starts at
1 and warn-and-proceeds by name through the approve-gate convergence pre-check (`:1483`), the
phase-6 open-PARTIAL check (`:1669`), the archive PARTIAL-closure check (`:2175`) and the archive
audit-converged re-query (`:2177`) -- on an initiative that never had a legacy shape. The doc tells
the operator this cannot happen.

**Fix**: (a) `` - `tokens.{input, output, cache_read, cache_write_5m, cache_write_1h}` -- raw counts ``,
and delete the now-redundant explanation duplication with `:467` or cross-reference it. (b) add
`verify-runtime`, `test`, `test-plan`, `test-coverage` with their real model/effort, or replace the
sentence with "every skill's model and effort is its own frontmatter; the testing layer is covered
by Sec.'Testing layer'". Bring `implement` into the effort sentence. (c) state the real behaviour --
`cmd_init` writes the literal `1`; `migrate-schema` is the only writer of any higher value -- and
say why (a fresh initiative has not been proven to satisfy the version-2 shape until the wave-B
fields exist). If writing 2 at init was the intent, that is a code change and belongs to a
correctness lens, not a doc edit.

---

### CA-073 (P2, STILL OPEN -- both halves): the timing harness invents the one number it is quoted for, and explains a ratio by a mechanism it disables

**Site**: `plugins/edm/bin/tests/timing.sh:308`, `:263-265`, header claim at `:7`.

**(a) `:308` prints an initiative count it never measured.**

```bash
echo "TIMING all_lint duration_ms=${ms} (${N_INITIATIVES} initiatives, budget <= 60000ms, CI budget not a commit-path budget)"
```

`N_INITIATIVES=50` is set at `:66` and is only ever changed by `--initiatives N` (`:74`), which is a
`--generate-fixture` option. `--all-lint` takes `--dir DIR` (`:20`, enforced at `:302`) and derives
nothing from what is in `DIR`. Point it at a 10-initiative fixture directory and it reports "50
initiatives" beside a duration measured over 10. The harness header at `:7` states "Every mode is a
REAL measurement against a REAL (generated) fixture -- no numbers are invented", and this is the
mode `CHANGELOG.md:202` quotes as the AC7 PASS evidence ("`--all` over 50 initiatives < 60,000ms |
1,671ms | PASS") -- so the one figure in the changelog that certifies the CI budget rests on a
constant, not an observation.

**(b) `:263-265` explains the ratio by a short-circuit the mode switches off.**

```
# environment. Files with no fence short-circuit the class without a per-line scan (T43), so
# the with/without ratio should stay near 1.0x for a corpus with few or no diagrams; this
# mode reports the measured ratio rather than asserting a fixed number.
```

`:284-287` appends a mermaid fence to **every** file in the fixture before the second measurement,
so at `edm-lint-artifacts:344` (`[[ -z "$mermaid_set" ]] && continue`) zero files short-circuit in
the run whose number is being produced. The stated cause is inactive for the stated effect. The
comment also says "should stay near 1.0x" while the line the mode actually prints (`:295`) declares
"budget: <= 1.40x", and `CHANGELOG.md:201` records the real measurement as 1.19x -- so the comment,
the printed budget and the recorded result state three different expectations.

**Fix**: (a) count the initiative directories under `${DIR}/SRD` at measurement time (or reuse
`edm-state list --paths | wc -l`) and print that; keep the constant only for fixture generation.
(b) rewrite to state the fixture honestly -- one diagram in every file, the worst realistic case,
short-circuit deliberately not exercised -- and quote the 1.40x budget the mode prints, not 1.0x.

---

### CA-069 (P2, PARTIAL -- one of three messages still wrong): the convergence waiver names `mode` when `mode` is not the trigger

**Site**: `plugins/edm/bin/edm-state:2132`.

Two of the three round-1 messages are fixed and verified:
- `:1423` -- `die "usage: edm-state approve-gate <PREFIX> <gate-num>|3.5|code-audit"`, all three
  legal forms, matching the implementation and the help block at `:17`. **Fixed.**
- `:2214` -- the archive re-query refusal now reads "...resolve the audit-converged failure before
  archiving (remediate findings / rerun a full round, **or repair the findings ledger data**)",
  which covers the invalid-JSONL and out-of-enum causes that no amount of re-auditing fixes.
  **Fixed.**

The third is unchanged:

```bash
if [[ "$(convergence_exempt "$mode" "$lifecycle_mode")" == "true" ]]; then
  echo "[warn] ${mode} mode -- skipping code-audit convergence check" >&2
```

`convergence_exempt` (`:704-715`) returns true for two independent reasons, and its own docstring at
`:690-692` says so: the mode has no implementation phase, **or** the lifecycle mode is
`fast-track`/`fix-pack`. On the second path `mode` is untouched, so a `standard`-mode / `fast-track`
initiative prints `[warn] standard mode -- skipping code-audit convergence check` -- and standard
mode is precisely the mode that requires one. The very next line, `:2136`, gets it right and names
both fields. Two adjacent lines still disagree about why the check was skipped, and the wrong one is
the `[warn]` an operator sees on stderr.

**Fix**: `echo "[warn] no code-audit round in this phase graph (mode=${mode}, lifecycle_mode=${lifecycle_mode}) -- skipping the convergence check" >&2`, or have `convergence_exempt` echo its
reason and interpolate it.

---

### CA-068 (P2, PARTIAL -- the AC8 row is untouched): the CHANGELOG still presents evidence it declares invalid 128 lines earlier

**Site**: `plugins/edm/CHANGELOG.md:203` against `:75-76`.

The duplication half is **fixed** -- the four byte-identical `Added` bullets are gone; the
`### Added (continued)` heading at `:444` now introduces five distinct bullets that appear once.

The evidence half is unchanged:

```
| AC8 | commit-hook scoping in `hooks.json:80-90` unchanged | `git diff --stat` shows zero changes to `hooks/hooks.json` | PASS |
```

`:75-76` of the same file: "**T67 AC8 asserted `hooks.json` had no uncommitted diff**, which goes
green after any commit whatever the content. Replaced with seven assertions on the scoping
properties it names." The verdict table still cites the retired evidence as the proof of PASS.

This round makes it concrete rather than theoretical: `hooks/hooks.json:86` **did** change during the
CA-011 remediation (the blocked-commit message now reads "Fix artifact violations or
edm-lint-artifacts setup/usage errors before committing"), so the AC8 row now asserts zero changes to
a file that changed, using a method the same document says cannot detect a change. The cited range
`hooks.json:80-90` is also now `:80-90` covering the `PreToolUse` block -- still roughly right, but
line-pinned into a file that is edited.

**Fix**: replace the Evidence cell with the seven scoping assertions `:76` refers to (name them or
name the smoke case that runs them) and drop the `git diff --stat` claim. Drop the `:80-90` line pin
in favour of the block name.

---

### CA-071 (P2, PARTIAL -- the colon-with-no-list survives in the sibling branch): a CI failure message promises a listing and exits

**Site**: `.gitlab-ci.yml:192`.

The header half is **fixed**: `:10-11` now reads "Every `image:` entry below is pinned to a
`@sha256:` digest **except the documented `bash:3.2` compatibility job, which is the one temporary
floating-tag exception**", and `:294` is indeed the only unpinned `image:`.

The message half moved rather than closed. The branch round 1 cited was the evals-size branch; the
banned-file branch beside it was already correct. Today:

```bash
if [ -n "$banned" ]; then
  echo "file-type-ban: banned file(s) found under plugins/:"
  printf '%s\n' "$banned"          # :174 -- earns its colon
  exit 1
fi
...
if [ "$evals_kb" -gt 100 ]; then
  echo "file-type-ban: tracked plugins/edm/evals/ content is ${evals_kb}KB, exceeds the documented 100KB budget:"
  exit 1                            # :192-193 -- colon, then nothing
fi
```

An operator whose pipeline fails here is shown a total, a trailing colon that reads as "the
offenders follow", and then the job ends. The one piece of information that would let them act --
which files grew -- is available (`git ls-files -- plugins/edm/evals` with sizes is already computed
in the `while` loop at `:181-188`) and is discarded.

**Fix**: drop the colon, or print the per-file sizes -- e.g. tee the loop's `wc -c` output into a
sorted list and `printf` the top offenders before `exit 1`, mirroring `:174`.

---

### CA-017 (P2, re-graded from P1; PARTIAL): the shared-pass comment still undercounts the sets it introduces, now two of four

**Site**: `plugins/edm/bin/edm-lint-artifacts:233-236`.

Two of the three round-1 defects are fixed. The false "40 percent budget is met by construction"
clause is gone. The self-contradicting "the three emitted classes" follow-on is gone. The
`:136-137` claim that class 4 works because "class 4 skips any line that is ignored" is gone, and
`:347-348` now correctly says the filtering is on the marker set via `EDM_MARKER_SET`.

The undercount survives the move and got worse by one:

```bash
# build_line_classes is called exactly once per file here, computed up front, and its two
# derived sets (ignore/mermaid) are reused by all four classes below -- a four-class lint run
# still costs one read of each file, not four.
```

The loop immediately under it, `:243-260`, derives **four** sets from the one table: `IGNORE_SETS`
(`:255`), `MERMAID_SETS` (`:256`), `MARKER_SETS` (`:257`) and `FENCE_DIAGS` (`:258`). `MARKER_SETS`
is a first-class consumer -- passed to `mermaid_scan_awk` at `:363` and the entire mechanism behind
the documented `edm-lint-ignore-start/end` escape valve inside a mermaid fence. `FENCE_DIAGS` drives
a violation class of its own at `:265-271` (`unterminated-fence`), which is a *fifth* violation class
the help block at `:20-28` does not list either -- the help enumerates four ("all cause a non-zero
exit") and `unterminated-fence` is reported by `report_violation`, which increments `violations`,
which produces exit 1.

Re-graded P1 -> P2: the actively false statements (the budget claim, the wrong escape-valve
mechanism) are gone, leaving an omission.

**Fix**: "its four derived sets (ignore / mermaid / marker / unterminated-fence)". Separately, add
`unterminated-fence` to the help block's violation-class list at `:20-28` so `--help` enumerates
every class that can produce exit 1.

---

### NEW-1 (P2): `CLAUDE.md`'s post-D32 pricing walkthrough states an arm order the code does not have

**Site**: `plugins/edm/CLAUDE.md:449-456` against `plugins/edm/bin/edm-state:368-426`.

The CA-012 rewrite is otherwise good and I am marking that finding fixed: the removed family
wildcards are gone from the prose, the inverted diagnostic is corrected (`:460-465` now states
plainly that an unrecognized in-family generation falls to `*)` and warns), and all twelve rate
figures at `:431-433` and `:442-444` match `edm-state:370-374` and `:384-412` cell for cell,
including the "frozen, not env-overridable" property of the previous-generation rows.

One claim did not survive checking. `:449` says "The `case` in `bin/edm-state` now has eight
explicit arms, **in this order**" and then lists the `unknown` sentinel as item 3, after all six
version arms. In the code, `unknown` is arm 6 of 8, sitting *between* `*haiku-4-6*` (`:390`) and
`*sonnet-4-7*` (`:407`):

| Doc order | Actual order (`edm-state`) |
|---|---|
| opus-4-7, sonnet-4-6, haiku-4-5 | opus-4-7 `:369`, sonnet-4-6 `:371`, haiku-4-5 `:373` |
| opus-4-8, haiku-4-6, sonnet-4-7 | opus-4-8 `:383`, haiku-4-6 `:390` |
| `unknown` | **`unknown` `:397`** |
| `*)` | sonnet-4-7 `:407`, `*)` `:414` |

The mismatch is behaviourally inert today -- a literal `unknown` cannot also contain `sonnet-4-7` --
but this passage exists *because arm order is the load-bearing property*: `:448` opens "D32 removed
the bare family wildcards" and the inline comment at `edm-state:376-377` explains the bug as "a bare
`*opus*` arm here would sit ahead of the `*)` warning arm". A contributor adding a Sonnet 5 row
(assigned to EDMV4 by D32 / CA-105) uses this list to decide where it goes, and the list is the one
artifact in the plugin that claims to be the map of arm positions.

**Fix**: reorder item 2 / item 3 to match the source, or -- better, since exact positions will drift
again -- replace "in this order" with a statement of the two ordering *invariants* that actually
matter: every explicit version arm precedes `*)`, and no bare family wildcard may be introduced
anywhere ahead of `*)`.

---

### NEW-2 (P2): the new shared lint library ships with no header, and the de-indent rationale was lost in the extraction

**Site**: `plugins/edm/bin/_edm-lint-lib.sh` (whole file, 101 lines).

The CA-050 extraction landed and is the right call -- `edm-lint-artifacts:52`,
`edm-check-vocabulary:57` and `edm-check-grants:101` all source it, and the round-1 "mirrored
VERBATIM from `build_ignore_set`" comments (CA-010) are correctly gone from both mirrors. But the
file that is now the single source of truth for three shipped binaries, two of which run in blocking
CI jobs, carries a shebang and nothing else. No statement of what it is, who sources it, that it is
sourced rather than executed, or what its three functions contract to.

Two specific losses, both of the "non-obvious design choice with no comment explaining the
constraint" kind this lens exists to catch:

1. **The de-indent is undocumented.** `:28` (`sub(/^[[:space:]]+/, "", fence_body)`) is the change
   that makes fences indented inside a numbered list or step count as fences. Round 1 recorded that
   this behaviour "was changed this initiative to de-indent, **with the reason committed inline**",
   and that the two hand-copies not following it produced false positives on roughly 60 indented
   fences in a blocking job. The copies are gone; so is the reason. It now reads as an incidental
   `sub()`. The user-facing half of the contract survives at `edm-lint-artifacts:41-42` ("including
   fences indented inside a numbered step or list item"), but nothing at the implementation says
   *why* the de-indent must not be removed, and the linter's help block is not where a contributor
   editing the awk will look.
2. **`report_violation` has two incompatible signatures and neither is documented.** `:86-89`
   dispatches on `$#`: the 4-arg form emits `path:line: class: snippet`
   (`edm-lint-artifacts`, `edm-check-vocabulary`), the 5-arg form emits
   `kind: name: class: path:line` (`edm-check-grants:243`) -- a different field *order*, not just a
   different field count. Both current callers happen to match their own documented Output format
   (`edm-lint-artifacts:30`, `edm-check-vocabulary:46`, `edm-check-grants:47-50`, all three verified
   correct), so this is latent rather than live -- but a fourth consumer added later has nothing to
   read except an arg-count `if`, and the arity error at `:91` is the only text in the file.

Also undocumented: the function emits four classes (`ignored`, `marker`, `mermaid`,
`unterminated-fence`) as a tab-separated table, and `:95-99` silently accepts *either* a lowercase
`violations` or an uppercase `VIOLATIONS` counter from the sourcing script's scope and silently
counts nothing if neither exists.

**Fix**: a header block stating the file is sourced (never executed), its three consumers, the
tab-separated four-class output contract of `build_line_classes`, the two `report_violation` forms
with an example of each, and the `violations`/`VIOLATIONS` convention. Restore the de-indent
rationale as a comment on `:28`, naming the false-positive class it prevents.

---

### NEW-3 (P2): "Mirrored verbatim in <one file>" names one of ten sites, and the family is not verbatim

**Site**: `plugins/edm/bin/edm-state:8` and `plugins/edm/bin/edm-lint-artifacts:5`.

Each of the two headers closes with a cross-reference to exactly one sibling:

- `edm-state:8` -- "Mirrored verbatim in edm-lint-artifacts (same fix, same reason)."
- `edm-lint-artifacts:5` -- "Mirrored verbatim in bin/edm-state (same fix, same reason)."

The sentinel-plus-awk extractor now exists in **eleven** files: `edm-state:98`,
`edm-lint-artifacts:61`, `edm-check-grants:63`, `edm-check-vocabulary:70`, `edm-init:21`,
`edm-validate-prefix:21`, `edm-check-skill-sync:28`, `edm-compare-eval:35`,
`evals/run-eval.sh:57`, `evals/score-artifacts.sh:91`, `evals/tiering-matrix.sh:67`. The CA-005
remediation added nine and updated neither cross-reference. A maintainer changing the extractor form
who trusts this line edits two files and misses nine.

"Verbatim" is also no longer true even of the pair's own family. Two distinct forms are in the tree:

```bash
# form A -- edm-state:98, edm-lint-artifacts:61, edm-check-grants:63, edm-check-vocabulary:70, ...
awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f' "$0"
# form B -- edm-check-skill-sync:28, edm-compare-eval:35, evals/tiering-matrix.sh:67
awk '/^# EDM-HELP-BEGIN$/{f=1;next} /^# EDM-HELP-END$/{exit} f{sub(/^# ?/,"");print}' "$1"
```

Form A keeps the `# ` prefix on every help line; form B strips it. So `edm-state --help` and
`edm-compare-eval --help` render differently, and the two headers claiming "verbatim" describe a
convention that has two variants.

Also still outside the convention: `edm-sync-canonical-sections:43` is a third form
(`awk '/^# edm-sync-canonical-sections/{f=1} f{print} /^set -euo pipefail/{exit}' "$0" | sed '$d'`),
keyed on the position of the `set -euo pipefail` line. It happens to print the full header today,
so it is not currently inaccurate -- but it is the exact fragility the sentinel convention was
introduced to remove, and it is the one `bin/` script the sweep did not reach.

**Fix**: replace both cross-references with "the same sentinel convention is used by every `bin/`
helper and the three `evals/` drivers; see `bin/_edm-lint-lib.sh`" (or wherever the extractor is
eventually shared from), and settle on one of the two awk forms. Add `EDM-HELP-BEGIN`/`END`
sentinels to `edm-sync-canonical-sections` so the family has no exception left for a comment to
misdescribe.

---

### NEW-4 (P2): a smoke assertion's label and failure message name `build_ignore_set`, a function that exists nowhere

**Site**: `plugins/edm/bin/tests/wave7-smoke.sh:296-299`.

```bash
echo "T03 AC8 -- mirrors (not re-derives) edm-lint-artifacts's report_violation/build_ignore_set/is_ignored_line"
t03_mirror_hits="$(grep -c 'report_violation\|build_ignore_set\|is_ignored_line' "$EDM_CHECK_GRANTS" || true)"
...
  || fail "AC8 -- report_violation/build_ignore_set/is_ignored_line not found in edm-check-grants"
```

`build_ignore_set` does not exist in the tree: a search across `plugins/edm/` returns only these
three lines. Round 1 (CA-010) reported the same dead symbol name in the `edm-check-grants` and
`edm-check-vocabulary` comments; those two were correctly rewritten and the mirrors deleted outright
in favour of the shared library. This third occurrence -- in the assertion that guards the very
relationship CA-010 was about -- was not.

This is the failure shape the round-2 brief flagged as this lens's blind spot: the described symptom
was fixed in two files and a third copy of the same stale claim was left standing. Two aggravating
details:

- The alternation means the assertion still passes on the other two names, so the dead name is
  invisible to CI. It pins the drift instead of catching it -- the same criticism round 1 made of
  this exact assertion.
- The label also attributes all three functions to `edm-lint-artifacts`. Since the extraction they
  live in `bin/_edm-lint-lib.sh`; `edm-lint-artifacts` is now a peer consumer, not the owner. So a
  developer reading the failure message is sent to the wrong file to look for a function with the
  wrong name.

**Fix**: `echo "T03 AC8 -- sources the shared lint library rather than re-deriving it"`, grep for
`_edm-lint-lib.sh` plus `build_line_classes`, and drop `build_ignore_set` from both the label and
the pattern. Consider the check round 1 asked for: any comment or label naming a mirrored symbol
must name a symbol that exists.

---

## Noted / Not Actionable

- **`plugins/edm/CHANGELOG.md:444` -- the `### Added (continued)` heading survives.** The duplicate
  bullets it separated are gone and the five bullets under it are unique. A second `Added` block
  after `### Changed` is unusual for Keep-a-Changelog, but nothing it states is false. Structural
  preference, not a documentation-accuracy defect.
- **`plugins/edm/bin/edm-state:3231` -- `(expected: open|fixed|noted)` still omits `deferred`.**
  Confirmed unchanged and confirmed still deliberate; the comment at `:3219-3221` now explains
  in place that a legacy `deferred` line is re-opened rather than rejected, so the omission is
  documented at the site. Advertising abolished vocabulary in an operator-facing list would
  contradict the policy `edm-check-vocabulary` enforces. Stronger NOTED than in round 1.
- **`plugins/edm/bin/edm-state:397-400` -- "tokens are necessarily 0" on the `unknown` arm.** Still
  false in the one narrow case (a message with no `.message.model` but non-zero tokens); pricing is
  identical either way. Intentional approximation, unchanged disposition.
- **`plugins/edm/bin/edm-sync-canonical-sections:43` -- the third help-extractor variant.** Verified
  it currently prints lines 2-29, i.e. the complete header including Usage. Nothing it prints is
  wrong today. Raised under NEW-3 as a fragility cross-reference only, not as a standalone L6
  finding, since no operator-facing statement is currently inaccurate.
- **`plugins/edm/bin/edm-state:352-364` pricing header and `CLAUDE.md:426-446` rate tables.** All
  twelve current- and previous-generation rate rows cross-checked cell by cell against
  `edm-state:370-374` and `:384-412`; the env-override variable names at `CLAUDE.md:446` and
  `edm-state:357-359` match the ones the code reads; the "frozen, not env-overridable" claim for the
  previous generation is true (`:370-374` are literals). No finding.
- **`plugins/edm/evals/README.md:74-75` and `:233-234`.** Re-checked explicitly for the
  "fixed in the first place only" failure mode the brief asked about: both figures are correct in
  **both** locations and both match `run-eval.sh:233-234`. The 913s measured audit phase at `:233`
  is now consistent with the 2700s cap it is quoted against. Clean.
- **`CLAUDE.md:105` / repository-root `CLAUDE.md` (CA-127).** Still records edm at v2.1.0 with a
  13-skill list against `plugin.json`'s `3.1.0` and 14 skills on disk (`verify-runtime` absent).
  Re-confirmed inaccurate, but repository-root `CLAUDE.md` is outside this round's stated file
  scope (which names only root `.gitlab-ci.yml` and `.gitignore`). Routed, not filtered.
- **`plugins/edm/README.md:105-151`.** Spot-checked the operator-facing surface: the slash-command
  table lists all 14 skills including `/edm:verify-runtime` at `:119`, the `--lenses` partial-round
  caveat at `:118` matches `bin/edm-state:3257`, and the agent table's model column at `:132-151`
  matches every agent's frontmatter and `CLAUDE.md:317-323`. No finding -- notable because the
  README is *more* accurate than `CLAUDE.md:325` on the same subject.
- **`.gitignore`.** Carries the `*.tmp.*` entries CA-015 asked for and contains no comments to be
  inaccurate. No finding.
- **`plugins/edm/bin/edm-lint-artifacts:373`, `:374`, `:409` (CA-044).** Re-verified rather than
  taken from the ledger: `${PREFIX}` (twice, including inside the `edm-state init ${PREFIX}`
  remediation instruction), `${INIT_DIR}` and `${PATH_ARG}` are all present and interpolated. The
  instruction now names an argument `cmd_init` accepts. Confirmed fixed.
- **`plugins/edm/bin/edm-lint-artifacts:31-35` and `hooks/hooks.json:86` (CA-011, L6 half).** The
  help block no longer claims the hook distinguishes exit 1 from exit 2; it states the truth, that
  the hook blocks on any non-zero and prints one generic line. The hook's message was widened to
  "Fix artifact violations **or edm-lint-artifacts setup/usage errors** before committing", so it no
  longer blames violations for an environment error. Whether exit 1 versus exit 2 *should* map to
  one outcome in a `PreToolUse` hook is L3's question, not this lens's. Doc half fixed.
- **`plugins/edm/bin/edm-lint-artifacts:274-279` and `:133-135` (CA-072).** Only the class-1 comment
  now claims the 39,872 ms measurement, and it attributes it to a specific mechanism it can own
  (~20,000 `echo | tr` forks). The class-4 comment claims only that it "made this class the dominant
  cost of a whole-tree lint **once class 1 was fixed**", which is consistent with, not competing
  with, the class-1 claim. The duplicate sole-authorship is gone. Fixed.

## Not examined

No Bash at runtime, so nothing was executed and no measurement or exit code was reproduced;
every verdict above is a static read. Not examined this round: the bodies of `wave3`, `wave4a`,
`wave4b`, `wave5`, `wave6` smoke suites (only `wave6:3110-3150` and `wave7:262-299`, `:594-599`,
`:1381-1382`, `:1684-1689` were read); `evals/score-artifacts.sh` beyond its help sentinels;
`evals/tiering-matrix.sh` beyond its help sentinels; `bin/edm-compare-eval`,
`bin/edm-check-skill-sync`, `bin/edm-init`, `bin/edm-validate-prefix` beyond their help blocks;
`monitors/monitors.json`; `docs/audit-patterns/*`; the 14 SKILL.md bodies beyond frontmatter and
the severity sections; and 28 of the 30 agent bodies. The CHANGELOG's "1401 assertions" figure at
`:78` remains unverified -- not statically countable.

## Handover notes for the synthesizer

Counts this round for L6: **6 open** (CA-017, CA-018, CA-068, CA-069, CA-070, CA-071, CA-073 -- that is 7 open of which CA-018 is L10's ID re-graded here), **4 new** (all P2, IDs to be assigned), **5 confirmed fixed** (CA-005, CA-011, CA-012, CA-031, CA-044, CA-072 -- 6), **3 still NOTED**.

Two items the synthesizer should weigh:

1. **CA-070 received no edit at all.** It was in Wave 6 item 13 of the remediation plan alongside CA-005, CA-011, CA-012, CA-031, CA-068, CA-069, CA-072 -- every one of which got at least a partial edit. CA-070 is the only member of that batch with zero applied changes across all three of its halves. Worth checking whether it was dropped from the editing pass rather than attempted and missed.

2. **Root cause 3 from round 1 ("prose describing pre-change code, in files that are themselves the contract") is still live, and its new expression is partial application.** Five of the seven still-open findings are cases where the remediation edited one of two or three cited sites: CA-068 (duplicate bullets deleted, AC8 row untouched), CA-069 (two messages of three), CA-071 (header fixed, message not), CA-017 (two defects of three), CA-018 (legacy scale removed, restatement kept). NEW-4 is the purest instance -- CA-010's dead symbol name was fixed in the two source comments and left in the test assertion that guards them. A mechanical guard is warranted: a check that no comment or test label names a shell function absent from the tree would have caught NEW-4 and CA-010's residual at zero cost.

Files with open L6 findings (all absolute):
- `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md` (:411, :325, :774-775, :449-456)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/CHANGELOG.md` (:203)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state` (:8, :2132)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts` (:5, :20-28, :233-236)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/_edm-lint-lib.sh` (whole file)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/timing.sh` (:263-265, :308)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh` (:296-299)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/agents/edm-audit-synthesizer.md` (:85-90)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/agents/edm-srd-auditor.md` (:65-70)
- `/Users/darryl.porter/projects/marketplace/.gitlab-ci.yml` (:192)
