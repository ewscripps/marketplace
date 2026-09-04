# QC Audit Report: EDMV4 Wave 5 -- Audit Lenses + Cross-Cutting [Shard 1/1]

**Date**: 2026-09-03
**Tickets audited**: EDMV4-T28, EDMV4-T50, EDMV4-T51, EDMV4-T52, EDMV4-T53
**Branch**: `edm/edmv4-ecc-integration` @ `6386a52` (main working tree)
**Method**: every zero-count assertion in scope was re-executed against the live tree, and every
negative fixture in `EDMV4-T28`'s set was extracted and run standalone. `run-all.sh` was not run.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T28 | Specify and enforce the house lens contract for the three new lens agents | PASS |
| EDMV4-T50 | Extend the tree-wide bash-4 construct ban to every new script and the new smoke suite | FAIL |
| EDMV4-T51 | Verify the required-binary set is still `bash`, `jq`, `git` | FAIL |
| EDMV4-T52 | Verify ASCII-only artifacts by a manual `--path` sweep plus an explicit byte scan | FAIL |
| EDMV4-T53 | Land `wave8-smoke.sh` in `run-all.sh` and run the Definition-of-Done pass | FAIL |

---

## Detailed Findings

### EDMV4-T28: House lens contract -- PASS

All 12 acceptance criteria verified. **Both of the concerns raised against this ticket resolve in
the implementation's favour**, and I checked each by execution rather than by reading.

**The lens set is derived live, not hardcoded at fourteen.** `wave8-smoke.sh:4749` builds the file
set as `ls edm-audit-*.md | grep -v '^edm-audit-synthesizer\.md$' | sort`, and `:4761` cross-checks
that count against `ALL_LENS_IDS`'s own count sourced from `bin/edm-state` -- two independently
derived numbers that must agree. A fifteenth lens is checked automatically.

**All 16 fixtures discriminate.** I extracted `t28_contract_violations` (`:4767-4885`) into a
standalone harness and ran every fixture. Result: 15/15 negative fixtures fire their expected tag,
no `sed` script is a no-op (verified by `cmp` against the reference), and each mutation yields a
tightly scoped tag set rather than a shotgun. The 16th (`:4966`, extra-heading tolerance) correctly
returns zero violations. Two fixtures deserve specific credit: `:4954` swaps `## Output` and
`## Output Format` via a sed hold-space line swap, proving `HEADING_ORDER` still catches a
**reordering** and not merely a removal, which is exactly the discrimination the subsequence
tolerance could have destroyed.

Independent corroboration that the checker is not a rubber stamp: running it against
`agents/edm-audit-synthesizer.md` (deliberately outside the lens set) produces 13 distinct
violation tags, including `OPENING_FRAME`, `LENS_ID_UNRESOLVABLE`, `FAF_CRITERIA_COUNT` and
`RESIDUAL_RISK_PARAGRAPH` -- tags that have no negative fixture of their own but are proven live.

- [x] AC1: Frontmatter -- verified on all three; `edm-audit-silent-failures.md:1-14`,
      `edm-audit-type-design.md:1-14`, `edm-audit-behavioral-tests.md:1-14` each carry
      `name:`, block-scalar `description:` naming the lens number, the exact `tools:` line,
      `model: opus`, `effort: max`, `maxTurns: 30`, `color: cyan`, `disallowedTools: Edit, NotebookEdit`.
- [x] AC2: No new lens grants `Edit`/`NotebookEdit`. `wave7-smoke.sh:1689`'s CA-529 assertion globs
      `agents/edm-audit-*.md` **live**, so the three land in its set automatically; `sort -u` yields
      one distinct `tools:` line across all fifteen files. Re-verified clean.
- [x] AC3: `model: opus` / `effort: max` matches `CLAUDE.md`'s contested-audit-set row at 14 lenses
      / 18 agents. No downgrade taken.
- [x] AC4: Opening frame and mandate sentence present in all three (`:16` and `:18` of each);
      checker tags `OPENING_FRAME`/`MANDATE_SENTENCE` proven live against the synthesizer.
- [x] AC5: House Scope paragraph present in all three; `wave7-smoke.sh:4949`'s T46 AC1 count is
      computed from `T46_SCOPE13` itself (`:4943`), which includes all three, and its companion
      assertion at `:4955` pins exactly one unique phrasing tree-wide. See P2-1 below on the
      assertion's shape.
- [x] AC6: False Alarm Filter framing plus exactly three numbered criteria. **Both** named machine
      assertions confirmed to include the three new files: T25 AC8's `lens_files` list
      (`wave7-smoke.sh:2005`) and T46 AC2's `T46_LENSES` (`:4937`) each carry 14 names.
- [x] AC7: Two write paths keyed to the lens's own ID, ASCII reminder, `mkdir -p` rationale and the
      JSONL-authoritative sentence -- verified directly at `edm-audit-type-design.md:57-67` and by
      the checker returning zero violations for all 14 live lens files.
- [x] AC8: `CLAUDE.md Sec."Severity vocabulary"` citation plus the `docs/canonical-sections.md`
      anchor with both qualifiers (`resolved relative to the EDM plugin's own root`,
      `never the caller's cwd`) -- all three anchored from birth.
- [x] AC9: JSONL schema restated with the correct lens ID, the D22/CA-130 stale-cache clause, all
      five field-rule bullets and the residual-risk paragraph.
- [x] AC10: `## When this does NOT apply` present in all three. L12 (`:117-119`) and L14
      (`:100-102`) use the standard sentence; L13 (`:114-120`) carries the T26 AC3/AC4 conditional
      form, and the checker branches on `CONDITIONAL_LENS_IDS` live rather than hardcoding L13.
- [x] AC11: `color: cyan` matches `CLAUDE.md Sec."Agent color scheme"`, whose lens row reads 14.
- [x] AC12: `bash plugins/edm/bin/edm-check-grants` **executed by this audit: exit 0**. The smoke
      extension names each of the three in its own per-file `pass`/`fail` message (`:4892`/`:4894`)
      while deriving the set live -- the stronger of the two readings of "lists all three by name".

**Findings (non-blocking):**

- [P2] EDMV4-T28 | plugins/edm/bin/tests/wave8-smoke.sh:4793-4794 | AC5: the `SCOPE_PARAGRAPH` check
  is two substring greps with an unchecked gap between them. It matches
  `...say so in a` and `rather than quietly narrowing, widening or transforming it.` but never the
  44 characters in between (` sentence and continue with the task as asked `). A lens rewriting that
  middle clause passes the contract check. The wrap-tolerance is justified --
  `edm-audit-security.md:20-21` genuinely hard-wraps this paragraph and is the only file of fifteen
  that does -- but the fix is a third grep for the middle segment, not a two-sided approximation.
  Note the substance is separately protected: `wave7-smoke.sh:4955` asserts exactly one unique
  phrasing of the scope line tree-wide, so this hole is not currently exploitable.
- [P2] EDMV4-T28 | plugins/edm/bin/tests/wave8-smoke.sh:4962-4965 | AC-adjacent: the comment
  justifying the `HEADING_ORDER` subsequence tolerance names 3 files and 2 heading strings
  (`edm-audit-consistency.md`, `edm-audit-dry.md` / `## Process`; `edm-audit-dead-code.md` /
  `## Key Technique`). The live extent is **7 files and 4 heading strings** -- add
  `edm-audit-runtime.md` and `edm-audit-spec.md` (`## Process`), `edm-audit-test-quality.md`
  (`## Fixing gaps found here`) and `edm-audit-wiring.md` (`## Tracing Method`). The waiver itself
  is correct and I re-derived it independently; the understated justification is what stops a later
  reader re-deriving it.
- [P2] EDMV4-T28 | plugins/edm/bin/tests/wave8-smoke.sh:4927-4955 | AC12: nine checker tags have
  neither a negative fixture nor incidental live exercise: `DISALLOWED_TOOLS`, `EFFORT`,
  `OUTPUT_JSONL_PATH`, `SCHEMA_LENS_ID`, `ASCII_REMINDER`, `JSONL_STATUS_RULE` and all three
  `NA_CONDITIONAL_*` tags. The last three matter most -- they are the sole machine enforcement of
  L13's conditional-lens carve-out (the `cost is never a reason to skip this lens` guard), and
  nothing proves they can fire. One fixture per tag on a scratch L13 copy closes it.

---

### EDMV4-T50: Bash-4 construct ban -- FAIL

Seven of ten criteria hold. The three that fail are the two that define the ticket's own
anti-drift contract (AC1, AC2) plus a scope miss on the one file the ticket exists to cover (AC5).

Positive controls were checked for discrimination rather than presence, and they hold: the
construct sweep's control (`:5029-5039`) asserts **two** hits from a fixture carrying both a real
`declare -A` and a real `mapfile`, so a half-broken alternation is caught; the self-check's control
(`:5079`) appends a genuine usage to a scratch copy of `wave8-smoke.sh` and proves the five
exclusions do not swallow it; and the process-substitution check carries both a positive control
(`:5100`) and a **negative** control (`:5105`) proving the safe `done < <(...)` idiom is not
flagged. That last pair is the strongest anti-vacuity work in the ticket.

- [ ] AC1: **FAIL** -- no assertion recomputes T61 AC9's file set. See P0-1.
- [ ] AC2: **FAIL** -- the alternation is re-encoded as a second literal, which is precisely what
      the AC forbids, and it has already drifted. See P1-1.
- [x] AC3: No new or modified `bin/` file matches `T61_BASH4_RE` on a non-comment line. Verified by
      running the exact `T61_BASH4_RE` (with the `\{fd\}` arm) against `_edm-datadir-lib.sh`,
      `edm-gateguard`, `edm-hookify`, `edm-stop-gate`, `edm-repo-readiness` and `edm-bash-gate`:
      zero hits.
- [x] AC4: No bash-4 array construct is used as a constant. The one constant that would naturally
      be an array, `GG_EXEMPT_GLOBS_DEFAULT` (`bin/edm-gateguard:290`), is a delimited string. See
      P2-1 for the deviation from the prescribed idiom.
- [ ] AC5: **FAIL (partial)** -- the sweep covers the five new files but not `wave8-smoke.sh`,
      which the AC names explicitly. See P1-2.
- [x] AC6: `/bin/bash -n` over all five new files plus `edm-bash-gate` and `wave8-smoke.sh`,
      invoked as literal `/bin/bash` -- `wave8-smoke.sh:5113-5121`.
- [x] AC7: `/bin/bash <script> --help` exits 0 with non-empty output for all five executables --
      `:5125-5134`. The sourced-only shared library is excluded with its reason stated, correctly.
- [x] AC8: `/bin/bash --version` recorded in suite output at `:5138`. Confirmed on this host:
      `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)` -- the floor is real, not assumed.
- [x] AC9: No "or the deviation is documented" escape hatch for a bash-4 construct exists anywhere
      in the initiative. Grepped `SRD/edm/EDMV4__ecc-integration/` and `plugins/edm/`: three hits,
      all either scoped to `set -euo pipefail` (`srd.md:2499`,
      `tickets/epics/05-classifier-and-scorecard.md:446`) or the prohibition itself (`srd.md:3467`).
- [x] AC10: All three shellcheck directives in the new scripts are inline at their site with a
      reason -- `edm-hookify:168`, `edm-gateguard:89`, `edm-gateguard:299`. No file-level blanket
      disable in any new script or in `wave8-smoke.sh` (header `:1-12` verified clean).

**Findings:**

- [P0] EDMV4-T50 | plugins/edm/bin/tests/wave8-smoke.sh (absent) | AC#1: assertion does not exist.
  AC1 requires an assertion that recomputes `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f` and fails
  naming any of `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`, `edm-stop-gate`,
  `edm-repo-readiness` absent from it. **Nothing in the suite does this.** The only `-maxdepth 1`
  uses are `:3110` and `:5727`, both over `bin/tests` for suite discovery. `T50 AC1` appears in the
  file exactly once, at `:5367`, inside T52's band, as a comment citing it as precedent -- the AC is
  cited but never implemented. The ticket's own Description makes this the load-bearing criterion:
  the five new files are covered by T61 AC9 *only* because they sit at the top level of `bin/`, and
  AC1 exists to assert that membership rather than assume it. A new script placed in a `bin/`
  subdirectory silently escapes the ban with nothing to say so. Fix: add the membership assertion
  in T50's own band, deriving the set live and comparing against the five names.
- [P1] EDMV4-T50 | plugins/edm/bin/tests/wave8-smoke.sh:5005 | AC#2: the pattern is re-encoded, not
  referenced. AC2 says the assertion "**references** `T61_BASH4_RE` (sourced or re-read from
  `wave7-smoke.sh:1083`) and **never re-encodes the alternation as a second literal that can
  drift**." `T50_BASH4_RE` is a third independent literal, and the comment at `:5001-5003` states
  the deviation as a deliberate choice ("A real alternation built here (not sourced from
  wave7-smoke.sh's own $T61_BASH4_RE)"). **It has already drifted in both directions**: it omits the
  `\{fd\}` arm that `T61_BASH4_RE` carries -- so the `bin/tests/` self-check, the one gap this
  ticket exists to close, does not check `{fd}` redirection at all -- and it adds `local[[:space:]]+-A`
  that `T61_BASH4_RE` lacks. This is the same drift `wave7-smoke.sh:2539-2542` already exhibits and
  which AC2's own text cites as the reason for the prohibition. Fix: re-read the literal from
  `wave7-smoke.sh:1083` at test time (`grep -m1 '^T61_BASH4_RE=' | cut -d= -f2-`) rather than
  retyping it. The "chosen route is stated in a comment" half of AC2 is satisfied (`:5041-5056`).
- [P1] EDMV4-T50 | plugins/edm/bin/tests/wave8-smoke.sh:5093 | AC#5: the CA-472 process-substitution
  sweep excludes the file the AC names. AC5 requires the assertion to grep "the five new files
  **plus `wave8-smoke.sh`**"; `T50_PROCSUB_HITS` pipes through `grep -v '/tests/'`, so
  `bin/tests/wave8-smoke.sh` is filtered out of its own check. The substance currently holds -- I
  ran the identical pattern against `wave8-smoke.sh` directly and the only match is the positive
  control's own literal string at `:5100` -- but the assertion cannot detect a regression in the
  file it was written to protect. Fix: run `t50_procsub` against `$T50_SELF` explicitly, mirroring
  the `t50_self_scan` shape already used at `:5057` for the construct ban.
- [P2] EDMV4-T50 | plugins/edm/bin/edm-gateguard:290,299-300 | AC#4: the prescribed word-membership
  idiom `case " $LIST " in *" $item "*)` appears in **none** of the new scripts.
  `GG_EXEMPT_GLOBS_DEFAULT` is a comma-separated (not space-separated) string consumed by
  `IFS=','; glob_list=($globs)` into an indexed array. I grade this PASS rather than FAIL because
  the AC's purpose is met -- an indexed array is bash 3.2-legal, no associative array or
  bash-4 construct is used, and the word-membership idiom structurally cannot express the glob
  match this constant needs. Recorded so the absence reads as a deliberate, justified deviation
  rather than an oversight.

---

### EDMV4-T51: Required-binary set -- FAIL

Five of nine criteria hold. The three sweeps all carry real positive controls and none
self-matches, but every sweep is scoped `grep -v '/tests/'` while three of the nine ACs are written
against `bin/` as a whole -- and `bin/tests/` is exactly where the live counterexamples are.

**The `stat` work is the strongest part of the ticket and satisfies AC5 exactly as specified.**
`edm-gateguard:232` reads `mtime="$(stat -c %Y "$path" 2>/dev/null)" || mtime="$(stat -f %m "$path"
2>/dev/null)" || mtime=""` with its rationale at `:227`. The assertion (`:5255`) exempts the pair
**by shape**, not by filename, and its control (`:5261-5269`) proves both directions in one
assertion: an unpaired `stat -c` is caught **and** a paired fallback is exempted. A control that
proved only the first half would have permitted a blanket file exemption to pass as a shape rule.

- [ ] AC1: **FAIL (partial)** -- the interpreter sweep excludes `bin/tests/`. See P1-3.
- [ ] AC2: **FAIL (clause a)** -- the guarded-site half is excellent; the "fails on any `perl`
      invocation anywhere else under `bin/`" half is not met, and a live counterexample exists.
      See P1-4.
- [x] AC3: Positive control at `:5169-5179` writes a scratch `python3 -c` fixture and asserts the
      pattern fires. The sweep does not self-match: `wave8-smoke.sh`'s own pass/fail labels contain
      `python3`, `node` and `deno` as prose, but the scanned set excludes `bin/tests/`, so the
      labels are structurally out of range rather than accidentally so.
- [ ] AC4: **FAIL** -- the "POSIX coreutils" phrase half passes (`:5297`, with a control at
      `:5304`); the "every coreutil beyond the POSIX set is named in-file with its BSD/GNU
      divergence stated, or avoided" half is violated. See P1-5.
- [x] AC5: `edm-gateguard` probes both `stat -c %Y` (GNU) and `stat -f %m` (BSD) at
      `bin/edm-gateguard:232`; the smoke assertion catches an unpaired `stat -c` and exempts the
      pair by shape, proven in both directions by `:5261-5269`.
- [x] AC6: No `.js/.ts/.mjs/.cjs/.py` file under `plugins/edm/`, asserted over a live `find`
      (`:5273-5282`) with a scratch-`.py` positive control (`:5285-5292`). See P2-2 on the one
      exclusion.
- [x] AC7: `plugins/edm/CLAUDE.md` still carries the exact sentence "macOS and Linux only
      (bash 3.2+, `jq`, `git` required). Windows and WSL are unsupported." -- asserted by
      `grep -qF` at `:5311`. Verified present verbatim.
- [ ] AC8: **FAIL** -- two of the five scripts and the shared library have no jq-off-`PATH` test.
      See P1-6.
- [x] AC9: The AD1-reversal clause is recorded beside D14 in `decisions.md:21` in exactly the
      required form: "if AD1 is reversed to vendoring by any route -- `EDMV4-59` rejected at a later
      gate, or any subsequent decision directing vendoring -- the dependency addition (`node` ... or
      `python3` plus `pip install gateguard-ai` ...) is re-presented at a gate as an explicit
      dependency addition, never absorbed", followed by "An `EDMV4-05` rejection (D15) is NOT a
      trigger for this clause". Both halves present, including the R17 non-trigger.

**Findings:**

- [P1] EDMV4-T51 | plugins/edm/bin/tests/wave8-smoke.sh:5156-5160 | AC#1: the interpreter sweep does
  not cover "every file under `plugins/edm/bin/`". `t51_scan` pipes through `grep -v '/tests/'`, so
  `bin/tests/` -- eleven files including three smoke suites and `timing.sh` -- is outside it. That
  AC2 grants a `perl` exemption for `bin/tests/timing.sh` is proof `bin/tests/` was meant to be in
  scope: an exemption is only needed for something otherwise caught. A `python3` line added to any
  suite is invisible to this check. Fix: drop the `/tests/` filter from `t51_scan` and handle
  `timing.sh`'s `perl` through AC2's existing content-resolved exemption, which already works.
- [P1] EDMV4-T51 | plugins/edm/bin/tests/wave8-smoke.sh:5193 | AC#2 clause (a): the sweep does not
  fail on "any `perl` invocation anywhere else under `bin/`", and there is a live counterexample.
  `bin/tests/wave6-smoke.sh:3501` and `:3511` both run `printf '%s' "$g18_row" | perl -pe
  's/\\\|//g'` with **no `command -v perl` guard and no fallback** -- a hard perl dependency in the
  suite that the plugin's own required-binary contract says it does not have. The implementer
  recorded it in a comment at `:5185-5190` and scoped the sweep past it rather than failing on it.
  Documenting a known violation inside the assertion that exists to catch it converts the assertion
  into a note. Either the sweep covers `bin/tests/` and `wave6-smoke.sh` is fixed (a two-line `awk`
  substitution), or AC2 clause (a) is rewritten to say what it actually enforces. Clause (b) is
  sound and needs no change: `t51_check_guarded_perl` (`:5225-5245`) resolves `_now` and
  `_ms_between` by function-body content, requires guard < perl < else < fi in relative order, and
  additionally asserts the fallback branch invokes no perl (excluding `echo` diagnostics that merely
  name it) -- a genuine structural check, not a presence check.
- [P1] EDMV4-T51 | plugins/edm/bin/tests/wave8-smoke.sh:2073 | AC#4: an unpaired, undocumented
  BSD-only coreutil in a file this initiative adds. `t43_ac9_snapshot()` runs
  `find . -type f -exec stat -f '%N %z %m' {} \;`. `stat -f` is BSD-only, has no GNU arm, carries no
  BSD/GNU divergence note, and is the exact asymmetry AC5 forces `edm-gateguard` to handle three
  thousand lines later in the same file. It escapes **both** guards for the same reason: T51's own
  sweep filters `/tests/` (`:5193`) and `T61 AC11`'s divergence sweep filters `/tests/`
  (`wave7-smoke.sh:1223`). On a GNU host this snapshot silently returns empty for every file, so
  `T43_AC9_BEFORE` and `T43_AC9_AFTER` compare equal-and-empty and the no-write assertion built on
  them passes vacuously -- the failure is not merely portability, it is a second vacuous assertion.
  Fix: use the `stat -c ... || stat -f ...` pair shape `edm-gateguard:232` already establishes,
  which both sweeps then exempt by construction.
- [P1] EDMV4-T51 | plugins/edm/bin/tests/wave8-smoke.sh (absent) | AC#8: no jq-off-`PATH`
  degradation test exists for `edm-hookify`, `edm-repo-readiness`, or `_edm-datadir-lib.sh`. AC8
  requires "one test per script". Present: `edm-gateguard` at `:3387` (marker absent + jq off PATH
  -> exit 0, empty stdout/stderr) and `:4490` (jq missing on the gated path -> exit 1); and
  `edm-stop-gate` at `:2338`/`:2351` (edm-state off PATH and a broken jq shim -> exit 0 both times,
  matching its never-block contract). Missing entirely for the other three. The **code** is correct
  -- `edm-hookify:139` dies via a `die()` defaulting to exit 1 (`:71-75`, the hook-script contract)
  and `edm-repo-readiness:65` via a `die()` defaulting to exit 2 (`:50-54`, the CLI contract) -- so
  this is a test gap, not a behavioural defect. But AC8 is an assertion about tests, and two
  blocking-adjacent scripts have none.
- [P2] EDMV4-T51 | plugins/edm/bin/tests/wave8-smoke.sh:5279 | AC#6: the live `find` excludes
  `evals/fixtures/`, where `tiny-svc`'s four `.js` files live. The exclusion is defensible -- AC6
  says "No file is **added**", the fixture predates EDMV4 (EDMV3-T22), and it is the subject
  repository under evaluation rather than plugin code -- and the reason is recorded at `:5275-5278`.
  Recorded so the exclusion is visible as a scoped judgment rather than read as "no such file
  exists anywhere".

---

### EDMV4-T52: ASCII-only artifacts -- FAIL

Nine of eleven criteria hold, and the AC6/AC7 sanitization work is the best-engineered part of
wave 5. Two criteria fail, both found by execution rather than reading: AC6's single-emit-point
premise is provably false for `edm-hookify` (live reproduction below), and AC4's coverage
assignment leaves four new files under neither mechanism.

**AC6/AC7's positive controls are the model for the rest of the initiative.** Each single-site
check injects a *bypass* into a scratch copy and asserts the identical check then fails
(`:5620-5628`, `:5650-5660`, `:5674-5684`). That distinguishes "the sanitizer exists" from "the
sanitizer is the only path", which is the whole claim. AC7 additionally asserts the hookify fixture
**genuinely matched** (`:5507`) rather than trusting an empty allow, and records the
`jq -e .`-not-applicable case for `edm-stop-gate` explicitly rather than skipping it silently.

Note also that `t52_ascii_scan` (`:5347-5362`) probes for PCRE via `T52_HAS_PCRE` and falls back to
a POSIX character-class grep. That guard is correct and is precisely what makes this scan
non-vacuous on macOS -- see the cross-reference finding at the end of this report.

- [x] AC1: DoD item 5 satisfied. See P2-3 on the literal wording.
- [x] AC2: Byte scan over a live `find "${PLUGIN_DIR}/bin" -type f` (`:5382`) plus `hooks.json` and
      `monitors.json`, `LC_ALL=C` on both branches, failing with file and line. Live-derived, so a
      script added later is covered without a second edit.
- [x] AC3: Positive control at `:5389-5401` writes a scratch file with one real non-ASCII byte
      assembled at runtime via `printf '\xc3\xa9'`, so the needle never appears as a literal byte in
      the suite's own source -- the scan cannot self-match. It fires.
- [ ] AC4: **FAIL** -- four new files are under neither mechanism, and one named script is missing
      from the assignment. See P1-7.
- [x] AC5: `edm-lint-artifacts EDMV4` asserted exit 0 at `:5438-5446`.
- [ ] AC6: **FAIL** -- `edm-hookify` has a second, unsanitized emission path for rule-author
      content, reproduced live. See P1-8.
- [x] AC7: All three emit points driven with real non-ASCII bytes; both halves asserted (pure ASCII
      via the same `t52_ascii_scan`, and `jq -e .` where a JSON control channel exists).
- [x] AC8: `edm-check-vocabulary` asserted exit 0 at `:5448-5452`. **Executed by this audit: exit 0.**
- [x] AC9: Mermaid class 4 runs inside AC5's same `edm-lint-artifacts EDMV4` invocation, exit 0.
- [x] AC10: The two-half reach gap is written into the ticket Description and into
      `plugins/edm/CLAUDE.md` Sec."Artifact content conventions" (`:1176-1189`), which states
      explicitly that a clean `--path plugins/edm/` run "says nothing about `bin/`'s own scripts".
- [x] AC11: The `.claude/edm-hookify/*.json` uncovered surface is documented as an uncovered
      surface in `CLAUDE.md:1195-1200`, with both independent reasons named.

**Findings:**

- [P1] EDMV4-T52 | plugins/edm/bin/tests/wave8-smoke.sh:5330-5338, :5382 | AC#4: the coverage
  assignment leaves files under neither mechanism, which is the one thing AC4 forbids
  ("no new file this initiative adds is listed under neither"). Two distinct gaps:
  (a) `bin/edm-repo-readiness` -- a new `bin/` script this initiative adds -- is absent from the
  assignment comment, which names only `edm-gateguard`, `edm-hookify`, `edm-stop-gate`,
  `edm-bash-gate` and the shared library. It is in fact covered by AC2's live `find`, so this half
  is a record defect only.
  (b) **Materially worse**: `bin/tests/fixtures/code-audit/lens-L12.jsonl`, `lens-L13.jsonl`,
  `lens-L14.jsonl` and `lenses-run.txt` -- four new files added by `EDMV4-T32` -- are covered by
  neither. AC1's `--path` sweep cannot collect them (`collect_md_files` filters `-name '*.md'`) and
  AC2's byte scan explicitly excludes `bin/tests/fixtures/*` at `:5382`. Their only nominal coverage
  is `wave8-smoke.sh:1338`, which is vacuous on macOS (see the cross-reference finding). These four
  files therefore have **no effective ASCII coverage at all** on the plugin's primary platform.
  Fix: narrow the `:5382` exclusion from the whole `fixtures/` tree to the specific
  fenced-code-block fixtures that need it (`mermaid/`, `lint-lib/`), which brings
  `fixtures/code-audit/` back under the byte scan and closes the gap in one edit.
- [P1] EDMV4-T52 | plugins/edm/bin/edm-hookify:285-287 | AC#6: `edm-hookify` does not have a single
  emit point for rule-author-supplied content. The `L)` arm of the tag dispatch runs a bare
  `echo "$_rest"`, emitting the rule's `name` field (`:230`, `$parsed.name // $path`) to stdout with
  no sanitization, entirely bypassing `hookify_emit_match`. **Reproduced live**: a rule file whose
  `name` carries a real non-ASCII byte, run through `edm-hookify list`, puts that byte on stdout
  unmodified (1 non-ASCII byte on the emitted line). The AC6 check at `:5642` cannot see it -- it
  scans only `_mname`, `_maction` and `_mmessage`, never `_rest`. The ticket's own Technical Notes
  anticipated exactly this ("Verify that single-emit-point property holds before writing the
  sanitizer, since a second emit path would bypass it"); the verification was written against the
  `M)` path only. Blast radius is bounded -- `list` is an inspection command with no JSON control
  channel, and `edm-hookify eval` (the path both hook consumers use) emits only `M)` lines, so no
  hook decision leaks a byte today. But AC6's stated premise is false as written. Fix: route the
  `L)` arm through the same sanitizer, and add `_rest` to the `:5642` variable list so the check
  covers the path it missed.
- [P2] EDMV4-T52 | plugins/edm/bin/edm-bash-gate:72 | AC#6-adjacent: `edm-bash-gate` is the fourth
  hook consumer and has no sanitizing emit point of its own -- `printf '%s\n' "$HOOKIFY_OUT" >&2`
  re-emits whatever `edm-hookify eval bash` wrote. It is **not** an AC6 violation: AC6 names three
  consumers, `edm-bash-gate` is outside T52's Target Components (it is `EDMV4-T45`'s file, landed
  after this ticket was written), and its output is transitively ASCII-safe because
  `hookify_emit_match` sanitizes before `edm-bash-gate` ever sees it. Recorded because that safety
  is **transitive and unasserted**: nothing states hookify's sanitization as a precondition of
  `edm-bash-gate`'s emission, so the `L)` defect above (or any future hookify stdout path) would
  propagate straight through it with no local guard and no test.
- [P2] EDMV4-T52 | plugins/edm/bin/edm-gateguard:163, edm-hookify:262-264, edm-stop-gate:82 |
  AC#6-adjacent: the sanitizer literal `LC_ALL=C tr -c '\011\012\015\040-\176' '?'` is hand-copied
  **five times across three files** with no shared owner. All five are byte-identical today -- I
  diffed them -- so there is no live drift. But the three files have no common library
  (`_edm-cli-lib.sh` is sourced by two of them and would be the natural home), and the AC6 checks
  key on the marker string `LC_ALL=C tr -c`, so a copy that drifts in its *character set* while
  keeping the marker still passes every assertion in the ticket.
- [P2] EDMV4-T52 | plugins/edm/bin/tests/wave8-smoke.sh:5421-5429 | AC#1: the AC's literal text
  ("reports zero violations") is not achievable and the assertion applies two exclusions to
  compensate. **Executed by this audit**: `edm-lint-artifacts --path plugins/edm/` reports **74
  violations** -- 67 in `CHANGELOG.md` (historical entries) and 7 in `bin/tests/fixtures/` (the
  deliberately-invalid mermaid and lint-lib negative corpora). Zero in `skills/`, `agents/`,
  `docs/`, `evals/`, `CLAUDE.md` or `README.md`. I grade this PASS because AC1 self-identifies as
  Definition of Done item 5, whose own text scopes the zero-violation claim to "`skills/`, `agents/`
  and `docs/`", and because T52's Out of Scope explicitly excludes normalizing pre-existing
  violations. Both exclusions are recorded with reasons at `:5405-5419`. Recorded so the gap between
  the AC's wording and the command's actual output is visible rather than absorbed.

---

### EDMV4-T53: `run-all.sh` registration and the Definition-of-Done pass -- FAIL

Eight of twelve criteria hold, two fail, and two are runtime-only.

**AC2's registration proof is genuinely load-bearing and is the best assertion in wave 5.** It does
not merely grep for `wave8-smoke.sh` in `_PREFERRED_ORDER`. It extracts the live default
(`run-all.sh:41`), builds a scratch suite directory containing every member of that real order
**except** `wave8-smoke.sh`, runs the real `run-all.sh` against it, and asserts the refusal names the
missing suite exactly ("expected suite(s) not discovered: wave8-smoke.sh") and that the exit code is
non-zero. It then does the same for the floor: a set two below the live count, with
`EDM_RUN_ALL_PREFERRED_ORDER=""` so the first tripwire is out of the way, proving the **real,
unoverridden** `_MIN_SUITE_COUNT` default is what refuses. AC2(b) compares the extracted default
against a live `find` count, both computed at test time, and locates `_MIN_SUITE_COUNT` by the
literal string `_MIN_SUITE_COUNT="${EDM_RUN_ALL_MIN_SUITE_COUNT:-` rather than by line number, exactly
as the AC demands after the `5f90001` drift. Verified live: `run-all.sh:41` lists eight suites ending
in `wave8-smoke.sh`; `run-all.sh:102` reads `:-8}`; eight `*-smoke.sh` files exist.

- [x] AC1: `wave8-smoke.sh` is executable, sources `_harness.sh`, and emits
      `Results: ${PASS} passed, ${FAIL} failed` (`:5894`) -- all three asserted at `:5701-5709`.
- [x] AC2: Both halves, plus the two load-bearing proofs described above.
- [x] AC3: All four named scripts have at least three cases. `--help`: `edm-repo-readiness` at
      `:555`, and the gap for the other three closed at `:5817-5847`. Usage error:
      `edm-repo-readiness` exit 2 at `:601`/`:609`, `edm-gateguard` exit 1 at `:5851-5858`,
      `edm-hookify` exit 1 at `:2478`, `edm-stop-gate` exit 2 at `:2323`. Happy paths present for
      all four.
- [ ] AC4: **FAIL** -- the guard assertions are string comparisons, not the behavioural check the
      AC specifies. See P1-9.
- [x] AC5: Every exit code the **SRD** documents for a new script has a producing case --
      cross-checked at review time, not by count: `edm-gateguard` 0/1/2 (`:3636`, `:3676`, `:3657`),
      `edm-hookify` 0/1/2 (`:2385`, `:2478`, `:2434`), `edm-stop-gate` 0/2 (`:2297`, `:2323`),
      `edm-repo-readiness` 0/2 (`:556`, `:601`). See P1-10 for what the AC's scoping lets through.
- [x] AC6: No network or API operation. The self-scan at `:5884` is paired with a positive control
      (`:5872-5882`) that assembles the forbidden invocation from split string halves at runtime, so
      the suite's own source never contains the literal the scan hunts -- the self-match trap this
      initiative hit five times, correctly avoided here.
- [ ] AC7: **PARTIAL** -- static half verified, runtime half not performed. See runtime-check below.
- [ ] AC8: **PARTIAL** -- runtime-only. See runtime-check below.
- [x] AC9: Linux recorded as untested in `decisions.md` D43 (Wave 5, 2026-09-03) as a numbered
      decision with the named follow-on `LINUXV`, confirmed free via `edm-validate-prefix LINUXV`,
      and with the concrete-naming requirement (image tag plus the bash version that image ships)
      stated. `srd.md` Sec.3.4 item 2 states the same. Grepped the whole ticket pack: **no AC
      anywhere claims a Linux run**.
- [ ] AC10: **FAIL** -- the commands pass, but no result is recorded anywhere. See P2-4.
- [x] AC11: The `EDM_RUN_ALL_*` family still works after the AC2 edit. `harness-smoke.sh:285-391`
      drives all three knobs across seven branches, and T53's own two load-bearing proofs use all
      three against the real `run-all.sh` and get the expected refusals -- live evidence the
      overrides still bind to the values AC2 changed.
- [x] AC12: `plugins/edm/CLAUDE.md` Sec."Testing changes" needed no edit. Grepped `CLAUDE.md`,
      `README.md`, `docs/` and `run-all.sh` for suite-count prose: **zero hits**. The section states
      the run procedure as `bash plugins/edm/bin/tests/run-all.sh` (`:1519`), which is unchanged and
      still correct at eight suites. Satisfied without an edit -- recorded so that reads as verified
      rather than skipped.

**Findings:**

- [P1] EDMV4-T53 | plugins/edm/bin/tests/wave8-smoke.sh:3332-3341, :4584, :2234 | AC#4: no hook
  guard is ever executed. AC4 requires a case "asserting its `command -v` guard **exits 0** when the
  delegate script is off `PATH`". All three assertions are `jq`-extract-then-string-compare against
  `hooks/hooks.json`: `edm-gateguard`'s at `:3332-3341` (a `case` on the command prefix),
  `edm-bash-gate`'s at `:4584` and `edm-stop-gate`'s at `:2234` (both `check` string equality). They
  verify the guard's **text**, never its behaviour. Grepped the suite for any execution of an
  extracted `.hooks[0].command` with a restricted `PATH`: none exists. A guard with a typo
  (`comand -v`), or one whose delegate name no longer matches the installed binary, passes every
  one of these three assertions and then fails open -- or worse, blocks -- at runtime. Fix: for each
  of the three, run the extracted command string under `/bin/bash -c` with a `PATH` that excludes
  the delegate and assert exit 0. That is three lines each and turns a text check into the
  contract check `CLAUDE.md Sec."Hooks behavior"` actually records.
- [P1] EDMV4-T53 | plugins/edm/bin/tests/wave8-smoke.sh (absent) | AC#5/DoD: `edm-bash-gate`'s
  blocking path has **zero** test coverage, and no AC in this pack reaches it. The suite asserts it
  exists and is executable (`:4566`), that `hooks.json` carries its guard string (`:4584`), that
  `CLAUDE.md` documents it (`:4711`), that `/bin/bash -n` parses it (`:5113`) and that `--help`
  exits 0 (`:5125`). **Nothing drives a payload through it.** Its documented exit 2 -- the code that
  refuses a user's `Bash` tool call -- is never produced by any case in any suite, nor is its
  documented allow-path exit 0. Both AC scopes miss it for the same reason: AC3 enumerates four
  scripts by name and `edm-bash-gate` did not exist when the pack was written (`EDMV4-T45` added
  it), and AC5 is scoped to "every exit code **this SRD** documents", while `edm-bash-gate` appears
  nowhere in `srd.md` -- its exit contract lives in `CLAUDE.md:1267` and its own `EDM-HELP` block.
  I therefore grade AC3 and AC5 PASS on their literal scopes, both verified. This finding is against
  the Definition-of-Done pass itself: T53 is the ticket whose job is to confirm every new surface
  has smoke coverage, and a new blocking hook shipped without any. Fix: add three cases mirroring
  `edm-hookify`'s own `:2434`/`:2385` fixtures -- a `block` rule producing exit 2, a `warn`-only rule
  producing exit 0, and a setup condition (hookify off `PATH`) producing exit 0.
- [P1] EDMV4-T53 | plugins/edm/CHANGELOG.md:9-83 | AC#8/DoD item 8: the `[3.3.0]` entry omits every
  new executable this initiative ships. DoD item 8 requires "a new entry documenting the 11-to-14
  lens change **and every other user-visible change in this initiative**". The entry documents three
  things: the lens growth (`EDMV4-T21/T25/T26/T27/T29/T33`), the Mermaid budget re-derivation
  (`EDMV4-T01`) and the Phase 5 gate deadlock (`EDMV4-T54`). A repo-wide grep for
  `gateguard|hookify|stop-gate|repo-readiness|bash-gate` across `CHANGELOG.md` returns one hit, in a
  historical EDMV3 section, unrelated. So **three new blocking hooks ship in 3.3.0 undocumented** --
  `edm-gateguard` (`PreToolUse` `Edit|Write|MultiEdit`, denies first touch), `edm-bash-gate`
  (`PreToolUse` `Bash`, exit 2 refuses a command) and `edm-stop-gate` (`Stop`, exit 2 blocks
  completion) -- along with `edm-hookify`'s entire rules-as-data format, `edm-repo-readiness` and
  `_edm-datadir-lib.sh`. A user upgrading to 3.3.0 gets three new ways their tool calls can be
  blocked and no changelog line saying so. Root cause is a pack-level ownership hole rather than an
  implementer miss: `EDMV4-T33` AC11 scopes its entry to "the 11-to-14 change", `EDMV4-T54` AC9 to
  the gate fix and `EDMV4-T01` AC10 to the Mermaid figure -- **no ticket owns DoD item 8's "every
  other user-visible change" clause**, so nothing failed when it went unwritten. Fix: add Added
  subsections to the existing `[3.3.0]` entry for the hook family, the hookify rule format and the
  readiness scorer, each naming the exit contract a user can now hit. Do not edit historical entries.
- [P2] EDMV4-T53 | SRD/edm/EDMV4__ecc-integration/ (absent) | AC#10: the Definition-of-Done command
  results are not recorded anywhere. AC10 requires the five commands to be "run and each result
  recorded". Grepped `decisions.md`, `HANDOFF.md` and `qc/` for `edm-check-skill-sync`,
  `sync-canonical-sections --check` and `plugin validate`: no result record exists. Only DoD item 2
  is recorded, in commit `6386a52`'s body. **I executed all five as part of this audit and they
  pass**: `edm-check-grants` exit 0, `edm-check-vocabulary` exit 0, `edm-check-skill-sync` exit 0,
  `edm-sync-canonical-sections --check` exit 0, and `claude plugin validate plugins/edm/` reports
  "Validation passed with warnings" (one warning, the known and expected "CLAUDE.md at the plugin
  root is not loaded as project context"). The substance holds; the record did not exist until this
  report. Fix: fold these five results into `decisions.md` as the DoD item 3/item 4 evidence entry,
  alongside D43.
- [P2] EDMV4-T53 | plugins/edm/CLAUDE.md:1264 | out-of-AC: the `edm-gateguard` `bin/`-table row this
  ticket added is present and correct, and all five new scripts now have rows (`:1263-1267`). No AC
  in T53 requires it -- it is unscoped work landed under this ticket's commit. Recorded so it is
  visible as delivered-but-ungraded rather than mistaken for AC coverage.

**PARTIAL verdicts (runtime closure required):**

- [PARTIAL] EDMV4-T53 | AC#7: Scratch-tree isolation. The static half is verified --
  `wave8-smoke.sh:5744-5747` installs `EXIT`/`INT`/`TERM`/`HUP` traps around `mktemp -d` and
  releases them at `:5808`, and `_harness.sh:72-84`'s `harness_scratch_dir` handles the trap-quoting
  hazard correctly (deferred expansion, non-`local` variable). **runtime-check:** snapshot
  `git status --porcelain`, run `bash plugins/edm/bin/tests/wave8-smoke.sh` **in isolation** (not via
  `run-all.sh`, whose pass through `wave6-smoke.sh:4087-4099` deliberately mutates
  `docs/canonical-sections.md`), snapshot again, and assert no new entry is attributable to it. Not
  performed here: a code audit was running concurrently, and the suite writes into the live `SRD/`
  tree via `edm-state init T52NA` at `:5545`. No artifact records this snapshot having been taken.
- [PARTIAL] EDMV4-T53 | AC#8: `run-all.sh` green on macOS under `/bin/bash` 3.2.57.
  **runtime-check:** run `/bin/bash plugins/edm/bin/tests/run-all.sh` on macOS and assert zero
  failures, recording the aggregate **and the interpreter version** together. Not performed here by
  instruction. The recorded evidence in commit `6386a52` ("3241 passed, 0 failed across 8 suites,
  verified twice consecutively on a quiet tree with git status byte-identical before and after both
  runs") covers the aggregate but **not** the interpreter, which is the specific thing AC8 names --
  a run under a Homebrew bash 5.x would produce the same line and prove nothing about the floor.
  `/bin/bash` on this host is `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)`, so the
  interpreter is available; it is the binding of that interpreter to that run that is unrecorded.

No ticket-level PARTIAL is recorded via `edm-state record-partial-verdict` for T53: the ticket rolls
up to FAIL on AC4 and AC10, so it returns for remediation regardless, and recording it as PARTIAL
would misrepresent a FAIL ticket in the `OPEN_PARTIALS` ledger. The two runtime checks above are
re-run as part of that remediation.

---

## Cross-reference finding (outside this shard's five tickets)

- [P1] EDMV4-T32 | plugins/edm/bin/tests/wave8-smoke.sh:1338 | A zero-count assertion that is
  **provably vacuous on macOS**. `t32_nonascii="$(LC_ALL=C grep -l -P '[^\x00-\x7F]' ... 2>/dev/null
  || true)"` uses bare `grep -P`. **Verified on this host**: `/usr/bin/grep` (the macOS system grep,
  the plugin's own supported platform) has no `-P` -- `echo x | /usr/bin/grep -qP 'x'` fails. The
  error is swallowed by `2>/dev/null`, the non-zero exit by `|| true`, so `t32_nonascii` is
  unconditionally empty and the assertion at `:1341` passes on every macOS host regardless of file
  content. The identical scan is done **correctly** 4,000 lines later in the same file by
  `EDMV4-T52`, which probes with `T52_HAS_PCRE` (`:5347`) and falls back to a POSIX character class.
  Raised here rather than silently left because it is the sole nominal ASCII coverage for the four
  `fixtures/code-audit/` files that finding P1-7 shows are covered by nothing else. Fix: reuse
  `t52_ascii_scan`, which is defined in the same file.

---

## Remediation Required

Prioritised. PARTIALs are not remediated here -- they close via `/edm:verify-runtime`.

**P0 -- blocking**

1. `EDMV4-T50` AC1 -- implement the missing assertion. Add to T50's band in `wave8-smoke.sh` a check
   that recomputes `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f` and fails naming any of
   `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`, `edm-stop-gate`, `edm-repo-readiness`
   absent from it. Derive the set live; do not assert a count.

**P1 -- must fix before the DoD pass can be re-declared**

2. `EDMV4-T50` AC2 -- `wave8-smoke.sh:5005`: replace the retyped `T50_BASH4_RE` with a runtime
   re-read of `T61_BASH4_RE` from `wave7-smoke.sh:1083`. Restores the missing `\{fd\}` arm.
3. `EDMV4-T50` AC5 -- `wave8-smoke.sh:5093`: run the process-substitution sweep against `$T50_SELF`
   explicitly; `grep -v '/tests/'` currently excludes the file the AC names.
4. `EDMV4-T51` AC1/AC2 -- `wave8-smoke.sh:5156`, `:5193`: drop the `/tests/` filter and fix the
   unguarded `perl -pe` at `wave6-smoke.sh:3501` and `:3511`, or rewrite AC2 clause (a) to state
   what it enforces. An `awk` substitution replaces both perl calls.
5. `EDMV4-T51` AC4 -- `wave8-smoke.sh:2073`: replace `stat -f '%N %z %m'` with the
   `stat -c ... || stat -f ...` pair shape from `edm-gateguard:232`. Currently BSD-only, undocumented,
   invisible to both divergence sweeps, and vacuous on GNU.
6. `EDMV4-T51` AC8 -- add jq-off-`PATH` cases for `edm-hookify` (expect exit 1),
   `edm-repo-readiness` (expect exit 2) and `_edm-datadir-lib.sh`.
7. `EDMV4-T52` AC4 -- `wave8-smoke.sh:5382`: narrow the `bin/tests/fixtures/*` exclusion to
   `mermaid/` and `lint-lib/` so `fixtures/code-audit/`'s four new files come under the byte scan;
   add `edm-repo-readiness` to the `:5330` assignment comment.
8. `EDMV4-T52` AC6 -- `edm-hookify:285-287`: route the `L)` arm through `hookify_emit_match`'s
   sanitizer, and add `_rest` to the `:5642` variable list so the check covers the path it missed.
9. `EDMV4-T53` AC4 -- execute each extracted `hooks.json` guard under `/bin/bash -c` with a `PATH`
   excluding the delegate and assert exit 0, in place of the three string comparisons.
10. `EDMV4-T53` AC5/DoD -- add three cases for `edm-bash-gate`: block (exit 2), warn-only (exit 0),
    setup (exit 0). Its blocking path currently has no coverage of any kind.
11. `EDMV4-T53` DoD item 8 -- extend the `[3.3.0]` CHANGELOG entry to cover the three new blocking
    hooks, the hookify rule format, `edm-repo-readiness` and `_edm-datadir-lib.sh`. Assign the
    "every other user-visible change" clause to a named ticket; no ticket currently owns it.
12. `EDMV4-T32` (cross-reference) -- `wave8-smoke.sh:1338`: replace bare `grep -P` with
    `t52_ascii_scan`.

**P2 -- quality**

13. `EDMV4-T28` -- add a third grep for the unchecked middle of the Scope paragraph (`:4793`);
    correct the extra-headings waiver comment to 7 files / 4 names (`:4962`); add negative fixtures
    for the nine unexercised tags, the three `NA_CONDITIONAL_*` ones first.
14. `EDMV4-T52` -- give the five-times-copied sanitizer literal a single owner in `_edm-cli-lib.sh`.
15. `EDMV4-T53` AC10 -- record the five DoD command results in `decisions.md` (all pass; results
    captured in this report).

<!-- QC-SHARD-COMPLETE range=T28,T50,T51,T52,T53 assigned=5 audited=5 -->
