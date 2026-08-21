I have no `Write` or `Bash` in my delivered tool set (the CA-130 / D22 class, NOTED in the ledger -- not re-filed), so I could not create the two output files or run `git log` over `833a06d..HEAD`. Verification below is against the working tree at HEAD, which is what the "does the doc match the shipped code" question actually turns on. Both halves follow inline, per the fallback instruction.

## Findings (L6: Documentation Accuracy)

---

### L6-01 (P1, high) -- `plugins/edm/evals/baseline/README.md:50` -- the baseline-capture runbook still describes a four-dimension scorer; the shipped scorer has six, so the runbook tells the operator to reject every valid capture run

The Stage A/B/C remediation landed CA-462's sixth scorer dimension. `plugins/edm/evals/score-artifacts.sh:145` now declares:

```bash
DIM_NAMES=(requirement-id-coverage ac-testability mermaid-parse-success coverage-map-bidirectionality lens-jsonl-prose-agreement known-gap-recall)
```

with `SCORER_VERSION="1.1.0"` (`:137`) and `compute_dim6` at `:546-574`. Dimension 6 is gated only on `run.json` carrying `.fixture == "tiny-svc"` (`:551-553`), and **`run-eval.sh` writes `fixture: "tiny-svc"` on both the complete path (`:675`) and the partial path (`:152`)**, while `plugins/edm/evals/fixtures/tiny-svc/expected.json` carries all six gaps with `srd_match` patterns. So a wave-A capture run scores dimensions 1, 2, 3, 4 and 6, and skips only dimension 5 -- `dimensions_scored` is **5**.

`plugins/edm/evals/README.md` was correctly swept (`:197-199` "Exactly six dimensions ... CA-462 added the sixth with a `scorer_version` bump to 1.1.0"; `:217-220` documents dimension 6). **`evals/baseline/README.md` was not**, even though the same remediation batch edited that exact file twice (CA-461 at `:107-112`, CA-464 at `:11-14`). Stale sites:

- `:50-51` -- "Confirm all three runs have `complete: true` and **`dimensions_scored: 4`** ... before using any of them as the committed baseline." This is the file's one gating instruction and it can no longer be satisfied.
- `:56` -- heading `## Why four dimensions, not five`
- `:62-63` -- "records `dimensions_scored: 4` and a `dimensions_skipped` array of length 1 ... This is a **four-dimension baseline**, deliberately"
- `:63-67` -- "the first run that includes a code-audit round establishes its own **five**-dimension baseline" (it would now be six)
- `:77-84` -- variance table has rows for dimensions 1-5 only; no `known-gap-recall` row
- `:95-105` -- the JSON example's `per_dimension_range` object lists four dimension keys; `known-gap-recall` is absent
- `:116` -- "**Five** mechanical dimensions are proxies"
- `:119` -- "score identically on all four (or five) dimensions"

Why P1 rather than P2: this is the sole runbook for arming the only automated prompt-quality tripwire this initiative has, and the failure mode is silent-and-expensive. An operator spends three live `claude -p` runs (README's own `:269-271`: roughly $10-25 each, 30-60 minutes each), reads `dimensions_scored: 5`, and concludes the capture is broken -- or, worse, "corrects" it by hand. That is the same class CA-461 was rated P1 for, in the same file.

**Fix:** rewrite the section as a five-scored/one-skipped baseline (dimensions 1-4 and 6 score; dimension 5 is null on every wave-A run because `run-eval.sh` stops after `audit-srd`); add the `known-gap-recall` row to the variance table and the `per_dimension_range` example; correct `:116`/`:119` to six. **Coordinate with the test in the same change:** `plugins/edm/bin/tests/wave7-smoke.sh:830` and `:834` assert the literal string `four-dimension` against this README, so the stale text is currently pinned green by the 2182/0 suite -- the remediation is blocked until that assertion is updated too.

---

### L6-02 (P2, high) -- `plugins/edm/evals/score-artifacts.sh:4` -- the file-header comment says "exactly five dimensions" 18 lines above its own help text saying six

 4: # EDMV3-T22) into a scores.json with exactly five dimensions. No model is in the loop:
...
22: #   score-artifacts.sh --describe             Print the six dimension definitions
38: # The six dimensions, in fixed order (T23 AC1 originally fixed this at exactly five;
39: #   CA-462 added the sixth -- known-gap-recall ...

Line 4 sits **outside** the `EDM-HELP-BEGIN` sentinel (which opens at `:8`), so it is not reachable through `--help` and was missed by the CA-462 sweep that corrected everything inside the block. It is nonetheless the first sentence a contributor opening the file reads, and it directly contradicts `:22`, `:38-41` and `DIM_NAMES` at `:145`.

**Fix:** change `:4` to "with six dimensions" (or drop the count and let `:38` own it, which is the safer shape given `:38` already carries the history).

---

### L6-03 (P2, high) -- `.gitlab-ci.yml:353` and `plugins/edm/CLAUDE.md:1020` -- two unswept siblings of CA-463 still describe the evals budget as a "directory-size ceiling"

CA-463's remediation corrected `plugins/edm/evals/fixtures/tiny-svc/README.md:38-46` to the shipped mechanism (git-tracked byte sum, `runs/` excluded) -- verified correct. Two other sites making the same claim were not swept:

- `.gitlab-ci.yml:353-355`, the comment **directly above the code that implements it**: "`plugins/edm/evals/` has a documented 100KB **directory-size ceiling** (plugins/edm/evals/fixtures/tiny-svc/README.md)". The code at `:356-364` sums `wc -c` over `git ls-files -- plugins/edm/evals` and ceiling-divides; `:374` announces that `runs/` output is deliberately excluded. The comment also cites the tiny-svc README as its authority, and that README now says the opposite of "directory-size".
- `plugins/edm/CLAUDE.md:1020` (the `lint:file-type-ban` CI-table row): "Also enforces the documented 100KB **directory-size ceiling** on `plugins/edm/evals/`".

This is exactly the failure CA-463 described: a contributor reproducing a "directory size" locally after any eval run measures untracked `evals/runs/` output, gets a number far over 100KB, and concludes they broke a budget that is not actually breached.

**Fix:** replace "directory-size ceiling" with "100KB tracked-bytes budget (git-tracked files only; untracked eval output under `evals/runs/` is excluded)" at both sites, matching the wording CA-463 already standardised in the tiny-svc README.

---

### L6-04 (P2, high) -- `plugins/edm/CLAUDE.md:1021` -- the `lint:shellcheck` CI-table row omits `*.awk` from the job's exclusion list

The row reads: "`shellcheck` over `bin/*`, `bin/tests/*.sh`, and `evals/*.sh` **(excluding `*.txt`)**". The shipped job excludes both extensions (`.gitlab-ci.yml:244-250`):

```bash
case "$f" in
  # G24/CA-233 (round 5): *.awk added alongside *.txt -- edm-mermaid-rules.awk is plain awk source ...
  *.awk|*.txt) continue ;;
esac
```

The sibling `lint:bash-syntax` row at `:1015` gets it right ("excluding `*.awk` and `*.txt`"), which is what makes this a miss rather than a convention. A contributor reading the table concludes `bin/edm-mermaid-rules.awk` is shellchecked as bash and may "fix" nonexistent findings in it, or add a second `.awk` helper expecting coverage that does not exist.

**Fix:** change to "(excluding `*.awk` and `*.txt`)", matching the `lint:bash-syntax` row and the shipped `case`.

---

### L6-05 (P2, high) -- `plugins/edm/CLAUDE.md:883` -- the G25/CA-342 durability note names the wrong test file and describes a grep that would not count call sites

883: **Durability (G25/CA-342):** `wave6-smoke.sh` carries a computed assertion (grep -c the real
884: `schema_at_least(` call sites in `bin/edm-state` against the count named in this paragraph) ...

Two factual errors:

1. **Wrong file.** `wave6-smoke.sh` contains exactly one occurrence of `schema_at_least`, at `:2492`, and it is prose inside a comment ("phase-start's C-4 signal is schema_version (via the shared `schema_at_least()` helper)") -- not an assertion. The real computed assertion is in **`wave7-smoke.sh:4441-4456`** ("G25/CA-342: CLAUDE.md's `schema_at_least()` call-site count is computed, not self-describing prose"). A contributor sent to `wave6-smoke.sh` to update the pin after adding a call site will not find it, and the drift-guard the paragraph exists to advertise goes unmaintained.
2. **Wrong grep.** The assertion greps `schema_at_least "` (`wave7-smoke.sh:4447`). The pattern the paragraph names, `schema_at_least(`, matches the definition at `bin/edm-state:1497` plus the four comment mentions at `:2360`, `:2419`, `:2967`, `:3808` -- five hits, none of them call sites -- while the six real call sites (`:2228`, `:2366`, `:2424`, `:2969`, `:3813`, `:4555`) contain no literal `(`.

The counts the paragraph states are correct and verified: six call sites, and four of them (`cmd_phase_start`, `cmd_phase_complete`, `cmd_archive`, `cmd_gate_check`) carry a canonical `# requires schema_version >= N` comment across the five comment lines at `:2355`, `:2417`, `:2966`, `:3763`, `:3804` -- `cmd_gate_check` carries two. Only the pointer to the guard is wrong.

**Fix:** change `wave6-smoke.sh` to `wave7-smoke.sh` and quote the actual pattern (`grep -c 'schema_at_least "'`), or drop the parenthetical entirely and cite the case by its shipped label ("G25/CA-342 -- edm-state has exactly 6 real `schema_at_least()` call sites, matching CLAUDE.md").

---

### L6-06 (P2, high) -- repository-root `CLAUDE.md:61` -- the plugin registry entry reads `edm (v3.1.0)` while every version source of truth says `3.2.0`

The 3.2.0 release landed in this remediation batch and bumped:

- `.claude-plugin/marketplace.json:35` -> `"version": "3.2.0"`
- `plugins/edm/.claude-plugin/plugin.json:4` -> `"version": "3.2.0"`
- `plugins/edm/CHANGELOG.md:7` -> `## [3.2.0] -- 2026-08-16`

The repository-root `CLAUDE.md:61` still reads `- **edm** (v3.1.0) -- ...`. This is a fresh instance of the class **CA-127** closed at round 3 (which was the same registry line stuck at `v2.1.0` against a `3.1.0` manifest); the fix then did not leave anything behind to keep it in step, so it re-staled on the next bump. The skill list in the same bullet is still accurate (14 commands, matching the 14 on-disk `SKILL.md` files).

Scope note: root `CLAUDE.md` is not in this round's enumerated file list, but it is precedented as in-scope for this lens on this initiative (CA-127), and it is the first file a contributor to this repository reads.

**Fix:** update to `v3.2.0`. Durability, since this is the second occurrence: add a wave7 case asserting the version token in root `CLAUDE.md`'s edm bullet equals `jq -r '.plugins[]|select(.name=="edm").version'` of `marketplace.json`, in the same computed-count shape CA-460's fix already uses.

---

### L6-07 (P2, medium) -- `plugins/edm/README.md:205` -- `decisions.md` is listed as an "optional on-demand" artifact; the layout marks it always-present

205: See `CLAUDE.md` for the full v2.0 artifact inventory including optional on-demand files
     (`decisions.md`, `ROLLBACK.md`, `exec-report.md`, `post-deploy/`).

`plugins/edm/CLAUDE.md`'s layout block annotates `decisions.md` as **`(Must/always-present)`**, alongside `planning.md`, `srd.md`, `architecture.md` and `explorers/`; the other three named files are correctly `Should`/`Could` + `on-demand`. `decisions.md` is also load-bearing at runtime -- `skills/code-audit/SKILL.md:204-209` requires the gate approval be appended to it at every convergence, and CLAUDE.md's D15 section requires scope changes recorded there.

Not caught by the false-alarm filter: this is not a simplification for non-technical readers (three of the four items in the same parenthetical are correctly classified), and README is the user-facing document a new adopter reads before CLAUDE.md.

**Fix:** move `decisions.md` out of the parenthetical -- e.g. "...the full v2.0 artifact inventory, including always-present files this summary omits (`architecture.md`, `explorers/`, `decisions.md`) and optional on-demand files (`ROLLBACK.md`, `exec-report.md`, `post-deploy/`)."

---

### L6-08 (P2, medium) -- `plugins/edm/docs/audit-patterns/README.md:48` -- the documented pending-entry count command does not produce a count

48: The pending count is always `grep -c 'status: pending-review' docs/audit-patterns/*.md`
    computed at read time -- there is no mirrored count in `.edm-state.json`.

`grep -c` against a multi-file glob prints one `<file>:<count>` line **per file** (five library documents), not a total. An operator or agent running the documented command to answer "how many entries are pending?" gets five prefixed lines; if only one file happened to match, they get a bare number that under-reports the real total. The suite's own correct usage at `wave7-smoke.sh:3805` runs it against a **single** file, which is why nothing catches this.

This is the same bare-`grep -c` class this plugin has been actively remediating (CA-392 / commit `dfa71d3`, "replace four bare `grep -c` captures with `count_matches`/`count_matches_strict`"), so it is in-family rather than a stylistic quibble. Note the fix must be paired: `wave7-smoke.sh:3474` asserts this exact sentence verbatim.

**Fix:** state a command that actually totals, e.g. `` grep -o 'status: pending-review' docs/audit-patterns/*.md | wc -l ``, and update the `wave7-smoke.sh:3474` assertion string in the same change.

---

## Noted / Not Actionable

| ID | Item | Rationale |
|---|---|---|
| N1 | CA-463 remediation, `evals/fixtures/tiny-svc/README.md:38-46` | Verified correct against `.gitlab-ci.yml:356-374`; the `du -sk` claim is gone and the `runs/` exclusion is stated. Residual siblings filed separately as L6-03. |
| N2 | CA-464 remediation, `evals/baseline/README.md:10-14` | Verified: the numeric line range is retired for a by-name citation, and both named anchors exist (`run-eval.sh:30` env row, `:328` "Two sanctioned auth paths", `:344` the auth die). |
| N3 | CA-461 remediation, `evals/baseline/README.md:96-112` | Verified: example now names `total_range`, matching `bin/edm-compare-eval:102`; the claimed pin exists at `wave7-smoke.sh:8204-8209`; `per_dimension_range` is honestly labelled "no code reads it". |
| N4 | CA-467 remediation wording | Present in **all 11** lens agents plus the schema line in `skills/code-audit/SKILL.md:312` (my first grep found 10 only because `edm-audit-security.md:181-183` line-wraps the sentence -- content is identical, not drift). The claimed "smoke-test identity check" genuinely exists at `wave7-smoke.sh:1655-1686`, with a positive control at `:1680-1686`. No finding. |
| N5 | CA-471 remediation, `bin/edm-state:4438-4472` | Comment and code agree exactly, including the C-4 clause ("no pass directory or no `lenses-run.txt` ... left exactly as before" ? `if [[ -n "$_pass_dir" && -f "$_manifest" ]]`) and "non-empty and parses as JSON lines" ? `[[ ! -s ]] || ! jq empty`. Consistent with `CLAUDE.md`'s `round_type` row, `skills/code-audit/SKILL.md:143-149`, and `wave6-smoke.sh:861-910`. |
| N6 | CA-466 remediation | `tooling-notes.md` is now in both inventories (`CLAUDE.md:114`, `README.md:198`) and has a structural consumer (`agents/edm-audit-synthesizer.md:25`, `:194-195`). Verified. |
| N7 | CA-460 remediation | Verified by count: 8 `lint:` jobs, 11 `<<: *alpine_edm` consumers (`:90,159,180,199,232,280,338,386,439,510,559`), 3 `test` jobs on `needs: ["lint:bash-syntax"]`. `CLAUDE.md`'s table carries the `lint:hooks-shell` row and both count sentences are right in both files. |
| N8 | CA-152 pricing arm-order passage (`CLAUDE.md`) | Verified against `bin/edm-state`: eight arms at `:490, 492, 494, 504, 511, 518(unknown), 528, 535(*)`; `unknown` is arm 6 of 8 between `*haiku-4-6*` and `*sonnet-4-7*`, exactly as stated. |
| N9 | Other CLAUDE.md/README count claims | Spot-verified and correct: "39 subcommands" (39 listed, matching the dispatch pin); "All 14 skills are accounted for above" (14 on disk); `disable-model-invocation: true` present in all 14 `SKILL.md` files; ".gitlab-ci.yml:265 nine command-type hooks" (9 in `hooks.json`); "three additional CI bans" (`:125,133,141`); root-`docs/` `.pptx`/`.docx` targets of `README.md:32-33` both exist. |
| N10 | `CLAUDE.md:1027` and `.gitlab-ci.yml:733-745` "the **stub** scores.json's `complete: false` is visibly refused" | Imprecise but not misleading: `score-artifacts.sh` overwrites the stub before `edm-compare-eval` runs, but re-derives `complete:false` from `run.json` (`:644`, `:657`), so the named property genuinely reaches the comparer and triggers refusal condition 3 (`edm-compare-eval:70-75`, exit 2). Filter 1 -- the claim approximates the mechanism while the operator-visible outcome is exactly as documented. |
| N11 | `CHANGELOG.md:7`, `:128` use a Unicode em dash in release headings | Pre-existing house style on every release heading, and `CLAUDE.md Sec."Artifact content conventions"` already documents in writing that the plugin's own tree is scanned by no automatic invocation. Vocabulary/ASCII policy, not L6's mandate. |
| N12 | `CHANGELOG.md:123` "`WHATS_NEW.md` deleted as unticketed scope creep (CA-465, D59)" | Verified accurate -- no `WHATS_NEW.md` exists under `plugins/edm/`; the only top-level markdown files are `CLAUDE.md`, `README.md`, `CHANGELOG.md`. CA-465 is genuinely closed, not merely claimed. |
| N13 | `CLAUDE.md`'s `test:smoke` row naming `wave7-smoke.sh` by literal filename | `.gitlab-ci.yml:450-455` deliberately avoids naming a suite file, calling it "a second, silently-stale source of truth". CLAUDE.md doing so is a latent drift risk, but the statement is **currently true**, so there is nothing to correct under this lens today. |
| N14 | `evals/fixtures/tiny-svc/expected.json:57` GAP-06 `expected_requirement` contains deferral vocabulary | Real, but it is a vocabulary-policy/scope question (`evals/` is outside `edm-check-vocabulary`'s `SCOPE_ROOTS`), already covered by the open CA-465(b)/CA-470 dispositions. Not re-filed here. |
| N15 | Delivered tool set lacked `Write`, `Edit` and `Bash` | The D22/CA-130 class, `noted` with a do-not-re-file disposition in the ledger. Consequence for this round: no `git log`/`git diff` over `833a06d..HEAD` was possible, so remediation verification is against the working tree at HEAD rather than against the diffs; and both output files are delivered inline instead of written to `pass-9_2026-08-16/`. |

---

