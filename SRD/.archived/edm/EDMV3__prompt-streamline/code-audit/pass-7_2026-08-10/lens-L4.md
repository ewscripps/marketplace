# Lens L4 -- Test Quality (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

## Scope and coverage honesty

This round: `plugins/edm/bin/tests/wave7-smoke.sh` (full pattern grep + three
targeted reads) and `plugins/edm/bin/tests/_harness.sh` (assertion primitives).
**`wave6-smoke.sh` was not reviewed this round** -- the first grep attempt used
a wrong path and the run was cut short. Findings below are wave7-only; wave6's
~124 new round-6 assertions remain unaudited for L4. Two findings are marked
`[unverified]` where the assertion shape was inferred from the extraction line
without reading the comparison.

Key primitive, load-bearing for every finding: `check()` in `_harness.sh:26-34`
is **substring**, not exact:

```bash
# check <label> <expected-substring> <actual> -- pass when <actual> contains <expected-substring>.
if [[ "$actual" == *"$expected"* ]]; then
```

There is no exact-match assertion in the harness at all. Every `check` call is
therefore a substring claim, and several round-6 additions need exact or
scoped matching.

## Findings (L4: Test Quality)

### L4-01 (P1) -- Self-satisfying assertion: can never fail, by construction

`plugins/edm/bin/tests/wave7-smoke.sh:1004-1005`

```bash
check "G24/CA-233 -- this suite's own T61 AC10 twin uses the identical exclusion set" \
  '*.awk|*.txt) continue ;;' "$(cat "${PLUGIN_DIR}/bin/tests/wave7-smoke.sh" 2>/dev/null)"
```

The haystack is this file's own full text, and the needle literal appears **on
line 1005 itself**. `cat` of the file always contains the needle because the
assertion is in the file. The T61 AC10 twin loop could delete its exclusion
entirely and this still passes green. The immediately preceding assertion
(`:1000-1003`, exact `-eq 2` count against `.gitlab-ci.yml`) is correct -- only
the self-referential half is broken.

**Fix:** scope the haystack to the twin's actual `case` block, and exclude the
assertion line, e.g. extract with `awk '/T61 AC10/,/^done/'` over the loop
region, or move the shared exclusion into a single named variable
(`T61_EXCLUDE_GLOBS`) that both the CI job and the loop read, then assert on
the variable. Note `_harness.sh:207-208` (G2) already solved exactly this
self-match problem via `grep -vF "$g2_awc_this_file"` -- the pattern exists
in-tree and was not applied here.

### L4-02 (P1) -- Assertion labeled "bin/ table names..." passes on unrelated prose

`wave7-smoke.sh:1190-1196`

```bash
for t66_c in audit-converged render-ledger audit-round-complete migrate-schema; do
  grep -q -- "$t66_c" "$CLAUDE_MD_T66" || t66ac3_missing="${t66ac3_missing} ${t66_c}"
done
... pass "T66 AC3 -- CLAUDE.md's bin/ table names all four wave-B/C subcommands"
```

`grep -q` is unscoped over the whole 700-line `plugins/edm/CLAUDE.md`. All four
names demonstrably occur **outside** the `## bin/ helper scripts` table in that
file today: `migrate-schema` in the schema_version contract prose,
`audit-round-complete` in Cost tracking and the state-field table,
`render-ledger` in the `decisions.md` vs `findings-ledger.md` note,
`audit-converged` in the `audit_rounds` row. Delete all four from the bin/
table and this test stays green. It asserts nothing about the table it names.

Not a design choice: the very next block, `:1215`, scopes correctly with `awk
'/^## \`bin\// {f=1} f && /^##/{exit} ...'`. Round 6 added the scoped version
beside the unscoped one and left both.

**Fix:** reuse the `:1215` awk range extraction as the haystack for the
membership loop.

### L4-03 (P2) -- Unguarded terminal `grep` in a command substitution aborts the suite under `set -euo pipefail`

`wave7-smoke.sh:1186` and `:1911`

```bash
t66ac3_claude_count="$({ grep -oE '[0-9]+ subcommands' "$CLAUDE_MD_T66" || true; } | head -1 | grep -oE '^[0-9]+')"
t40_heading_order="$({ grep -n '^## ' "${PLUGIN_DIR}/CLAUDE.md" || true; } | grep -A2 'Severity vocabulary')"
```

`_harness.sh:5` documents that suites source the harness *after* `set -euo
pipefail`. The **first** grep in each is `|| true`-guarded; the **terminal**
grep is not. If the "N subcommands" phrase or the "Severity vocabulary" heading
is ever reworded, the assignment's exit status is 1 and the suite dies at line
1186 -- discarding ~1,400 later assertions in the largest suite. This surfaces
as a CRASH, not a silent pass, so it is not a false-green; it is a large silent
*coverage* loss behind one unrelated edit. The file documents the correct
convention itself at `:1236-1238` ("`grep -c` is guarded with `|| true`: a
zero-match grep exits 1, which would abort the suite") and then violates it
two lines of context away.

Same class, `pipefail` variant (no `|| true` anywhere on the pipeline): `:2018`,
`:2019` (`grep -rhoE ... | sort -u | wc -l`), `:358`, `:2392`, `:2393` (`ls ...
| wc -l`). A zero-match grep poisons the pipeline under `pipefail` even though
`wc -l` exits 0.

### L4-04 (P2) -- Guard asymmetry lets a count comparison pass on two empty extractions

`wave7-smoke.sh:1185-1189`

```bash
t66ac3_dispatch_count="$({ grep -cE '^  [a-z][a-z0-9_-]*\)[[:space:]]+cmd_' "$EDM_STATE" || true; })"
t66ac3_claude_count="$(... | grep -oE '^[0-9]+')"
[[ "$t66ac3_dispatch_count" == "$t66ac3_claude_count" ]] && pass "...count ($t66ac3_claude_count) matches the dispatch table ($t66ac3_dispatch_count)"
```

String equality of two independently-extracted values, neither validated as
numeric or non-empty. The pass message renders as `...count () matches the
dispatch table ()` in the both-empty case. Today `grep -c` always prints `0` so
the shapes differ and it fails -- but the assertion has no floor.

Separately, the dispatch regex undercounts by design: an alternation arm
(`foo|bar) cmd_foo`) counts as one subcommand while `--help` lists two, and any
arm whose `cmd_` body wraps to the next line counts as zero. Merging two
subcommands into one arm and decrementing CLAUDE.md keeps this green.

**Fix:** add `[[ "$x" =~ ^[0-9]+$ ]]` floors on both sides before comparing;
count arms by parsing the `cmd_` function definitions instead of the `case`
arms.

### L4-05 (P2) -- Repo-wide `grep -r` needles that match the assertion's own source

`wave7-smoke.sh:2018-2019`, `:2742` `[unverified]`, `:2798` `[unverified]`

```bash
t42_ac4_forms="$(grep -rhoE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions\\?"?' "${PLUGIN_DIR}/" 2>/dev/null | sort -u | wc -l ...)"
t34_old_sentence_hits="$(grep -rl "$t34_old_sentence" "${PLUGIN_DIR}/" 2>/dev/null | wc -l ...)"
t35_freetext_hits="$(grep -rn -e "$t35_freetext_needle_a" -e "$t35_freetext_needle_b" "${PLUGIN_DIR}/" 2>/dev/null | grep -v 'orchestrator/SKILL.md' || true)"
```

All three walk `${PLUGIN_DIR}/`, which contains `bin/tests/wave7-smoke.sh`,
where the needle literal is defined. `:2742` and `:2798` are "this string must
be gone" assertions whose baseline is therefore permanently >= 1 -- either the
threshold was tuned to absorb the self-hit (fragile: it silently allows one
real violation), or it accounts for it some other way not confirmed here.
`:2018`'s distinct-form count is inflated by its own regex literal.

The correct exclusions exist elsewhere in the same file and diverge from each
other: `:1444` uses `grep -v tests/` (unanchored), `:1817` uses `grep -v
"${PLUGIN_DIR}/bin/tests/"` (absolute), `:2742`/`:2798`/`:2018` use none. Three
exclusion vocabularies for one check class.

**Fix:** one shared `harness_grep_plugin_excluding_tests()` helper in
`_harness.sh`; make every repo-wide scan call it.

### L4-06 (P2) -- Positive controls derived from the pattern, not from the real regression

`wave7-smoke.sh:1267`, `:1277`, `:1287`, `:1425`, `:963`, `:1128`

```bash
t66ac12_flag_leak_control="$(printf '%s\n' 'synthetic control: code_audit_converged true' | grep -c "$t66ac12_flag_leak_pattern" || true)"
t66ac4_wrong_classes_control="$(printf '%s\n' 'a row mentioning missing version header' | grep -c "$t66ac4_wrong_classes_pattern" || true)"
```

The CA-037 control convention is good and merits credit. But in these six the
control string was **written to satisfy the regex**, so it proves only "the
regex compiles and matches a string invented for it" -- not "the regex matches
the shape the real violation had." A regex loosened during a later edit (say to
a bare `.*converged.*`) keeps both the control and the live scan green while no
longer detecting anything specific. `:2826`'s control (`'synthetic control:
Ask: "Do you approve of this plan?"'`) is the counter-example done right -- it
reproduces real prose.

**Fix:** copy control strings verbatim from the pre-fix text the finding was
raised against (git history has it), and say so in a comment.

### L4-07 (P2) -- Eval-script exit status discarded; two failed runs prove "determinism"

`wave7-smoke.sh:607-609`, `:635-637`, `:648-650`, `:678-680`, and `:556`

```bash
bash "$SCORE_ARTIFACTS" run-dir > out-dim2.json 2>/dev/null
d2="$(jq -r '.dimensions[1].score' out-dim2.json 2>/dev/null)"
```

The scorer's exit code is never checked and its stderr is discarded, so a crash
yields an empty JSON file and a `jq` failure that `2>/dev/null` swallows into
an empty `d2`. The same file demonstrates the right pattern at `:563` -- `jq -e
... || echo "ERR"` with an explicit sentinel -- and does not apply it to the
four dimension extractions.

Related, `:556`: `if diff -q out-a.json out-b.json` establishes run-to-run
determinism, but two *identically empty* outputs from two crashed runs also
satisfy `diff -q`. Partially mitigated by the separate `dim_count` assertion at
`:563`; a non-empty/valid-JSON precondition on both files before the `diff`
would close it outright.

### L4-08 (P2) -- Meta-assertions on test-code shape rather than behavior

`wave7-smoke.sh:2521`, `:1693`, `:1701`

```bash
t44_check_uses="$(printf '%s\n' "$t44_block" | grep -c 'check_fails\|check "' || true)"
t25_output_bullets="$(printf '%s\n' "$t25_output_section" | grep -c '^- `' || true)"
t25_defer_count="$(grep -ci 'defer' "$SYNTHESIZER_AGENT" || true)"
```

These count occurrences of test scaffolding or markdown bullets. `grep -c`
counts *lines*, not occurrences, so two hits on one line count once -- any
assertion of the form "expect N" is off-by-one-per-shared-line the moment
formatting changes. `:1701`'s `-ci 'defer'` is an unanchored, case-insensitive
substring: it fires on "deferred", "deferral", and any future word containing
the trigraph, which is conservative for an absence check but wrong if the
threshold is anything other than zero.

## Noted / Not Actionable

- **`|| true` on `grep -c` throughout** -- documented as deliberate at
  `wave7-smoke.sh:1236-1238` with the exact rationale ("a zero-match grep
  exits 1, which would abort the suite"). Correct and consistently applied on
  the ~60 sites where it appears. L4-03 is about the sites that *omit* it, not
  these.
- **`2>/dev/null` on `find`, `cat`, `ls` of optional paths** (`:65-70`,
  `:734-742`, `:1493-1505`) -- suppressing "no such file" on a path whose
  absence the following assertion is specifically testing. Intentional; the
  assertion still fails on empty content.
- **`grep -c ... -eq 0` absence checks** (`:1204` record-task-duration,
  `:2404-2418` fixture markers) -- substring matching is the conservative
  direction for an absence claim; a substring false-hit fails the test rather
  than passing it.
- **Entire suite asserts on prose content, not runtime behavior** -- inherent
  to a prompt-streamlining initiative whose deliverable *is* prose. Not a
  mock-abuse or coverage finding.
- **`with_scratch_repo` / `harness_scratch_dir` single-nesting constraint**
  (`_harness.sh:71`, `:96-97`) -- documented limitation with stated bash-3.2
  rationale (`trap -p` composition), not a hidden order dependency.
- **Deferred-expansion trap bodies** (`_harness.sh:76-85`) -- the CA-159/
  CA-232 comment explains the single-quote requirement and why a non-`local`
  variable is required. Correct as written.
- **`test:smoke-bash32` image not digest-pinned** -- documented exception
  with authorization and a named precondition in `plugins/edm/CLAUDE.md`;
  also an L7/L9 concern, not L4.

## Requested-but-not-found

**Stale citations by line number:** none found in wave7. Round-6 assertions
cite by heading string or by `awk` range, never by absolute line number. That
is the right convention and it held. Unverified in `wave6-smoke.sh`.

**Case-sensitivity mismatches:** only one candidate, `:2098` `grep -qi
"$MERMAID_REF"` -- case-insensitive where the eight sibling assertions on the
same reference (`:1980`, `:1993`, `:2003`, `:2108`) are case-sensitive. Given
`plugins/edm/CLAUDE.md` states the heading string is fixed and referenced by
name, the `-i` at `:2098` is an inconsistency that would accept `## mermaid
diagram conventions`. Filing as a sub-item of L4-05's consistency class rather
than a separate finding, since it is one character and low-impact.

**Next action for the parent:** L4-01 and L4-02 are the two that make green
builds lie and should land in this round's remediation. `wave6-smoke.sh` needs
a second L4 pass -- its round-6 additions are entirely unaudited.
</content>
