# Lens L4 -- Test Quality (round 8, full)

Scope: plugins/edm/bin/*, bin/tests/*, agents/*.md, skills/*/SKILL.md, hooks/hooks.json,
monitors/monitors.json, evals/*.sh, CLAUDE.md, README.md, CHANGELOG.md, .gitlab-ci.yml.
All line numbers verified against the working tree at commit bdab2ac.

## Findings (L4: Test Quality)

### L4-01 [P2] CA-401 still open -- unguarded terminal `grep`/`ls` in count pipelines aborts the whole suite

`plugins/edm/bin/tests/wave7-smoke.sh:8` sets `set -euo pipefail`. A command substitution whose
terminal (or any) pipeline stage exits non-zero fails the assignment, and `-e` then kills the
suite mid-file -- discarding every later assertion rather than failing one. The prior round's
sites are unchanged, and the class is wider than round 7 recorded:

- `:1195` `t66ac3_claude_count="$({ grep -oE '[0-9]+ subcommands' ... || true; } | head -1 | grep -oE '^[0-9]+')"`
  -- first grep guarded, terminal grep is not. Rewording "N subcommands" in CLAUDE.md kills the suite here.
- `:1937` `t40_heading_order="$({ grep -n '^## ' ... || true; } | grep -A2 'Severity vocabulary')"` -- same shape.
- `:358` `ls "$PLUGIN_DIR"/agents/*.md 2>/dev/null | wc -l | tr -d '[:space:]'` (no `|| true`).
- `:373-374` `grep -oE 'all [0-9]+ \`edm-audit-\*\`' ... | grep -oE '[0-9]+' | head -1` (no `|| true`).
- `:1322`, `:1501`, `:1504` -- same `ls ... | wc -l` shape, unguarded.
- `:2044`, `:2045` -- `grep -rhoE ... | sort -u | wc -l` and `grep -rhcE ... | awk ...`, no guard anywhere.
- `:3621`, `:3628`, `:3696` -- bare `grep -c '^### ' "$scratch_srd"` with no `|| true`.
- `:4296`, `:4300` -- bare `grep -c 'schema_at_least "' "$EDM_STATE"` / `grep -c '# requires schema_version >= '`.
- `:4394` -- `grep -rl 'before and after' ... | wc -l | tr -d ' '` with no guard.

The file documents the correct convention itself at `:1253-1254` ("`grep -c` is guarded with
`|| true`: a zero-match grep exits 1, which would abort the whole suite") and violates it at 15
sites. The guard-asymmetry half also stands: `:1196` compares `$t66ac3_dispatch_count` against
`$t66ac3_claude_count` with neither floored to `^[0-9]+$`.

**Fix:** route every count capture through the existing `count_matches` / `count_matches_strict`
helpers in `_harness.sh` (the shape `:7940`/`:7948` already uses after the CA-361 fix), and add
`^[0-9]+$` floors on both sides of `:1196` before comparing.

### L4-02 [P2] CA-402 still open -- repo-wide scan self-matches, four divergent exclusion vocabularies, one case-sensitivity outlier

- **Self-match (live):** `:2044`/`:2045` scan `${PLUGIN_DIR}/` for
  `CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions\\?"?`. `wave7-smoke.sh:2001` itself contains
  `MERMAID_QUOTED='CLAUDE.md Sec."Mermaid diagram conventions"'` -- inside the scanned tree. The
  self-hit is silently absorbed by the `>= 11` floor and counted in the `== 1` distinct-form check.
  (See L4-11: that variable has no readers at all.)
- **Four exclusion vocabularies, still no shared helper.** `_harness.sh` has no
  `harness_grep_plugin_excluding_tests()`. Live forms: `grep -v '/tests/'` (wave7:1033, :5700,
  :5708; wave6:2773), `grep -v tests/` unanchored (wave7:1461, :1474, :1479), `grep -v
  "${PLUGIN_DIR}/bin/tests/"` absolute (wave7:1843, :1850, :1855), `grep -v '/bin/tests/'`
  (wave7:3210; wave6:990), and none at all (wave7:2044, :2045).
- **Case inconsistency:** `:2124` uses `grep -qi "$MERMAID_REF"` where its four siblings on the
  same reference (`:2006`, `:2019`, `:2029`, `:2134`) are case-sensitive -- `:2124` would accept
  a lowercased heading the others reject.

**Fix:** one `harness_grep_plugin_excluding_tests()` in `_harness.sh` called by every repo-wide
scan; drop `-i` at `:2124`; delete `MERMAID_QUOTED` (L4-11).

### L4-03 [P2] CA-403 still open -- six positive controls authored to satisfy the regex, not copied from the real pre-fix text

All six cited controls are unchanged and none carries a provenance comment:
`:963` `'declare -A foo'`; `:1137` `'bash plugins/edm/bin/tests/wave6-smoke.sh'`;
`:1284` `'a row mentioning missing version header'`; `:1294` `'a row mentioning TaskCompleted'`;
`:1304` `'lifecycle_mode row still says partial'`; `:1442`
`'synthetic control: code_audit_converged true'`.

Each proves only "this regex matches a string invented to match it", not "this regex matches the
shape the real violation had". A regex loosened in a later edit keeps both the control and the
live scan green. `:2852`'s control (`'synthetic control: Ask: "Do you approve of this plan?"'`,
reproducing real retired prose) remains the in-file counter-example done right.

**Fix:** replace each control string with the verbatim pre-fix text from git history and add a
one-line comment beside each naming the commit it was copied from.

### L4-04 [P2] CA-404 partially open -- four scorer-extraction sites still discard exit status and stderr

The determinism half is closed (see Noted). Still open: `:607`, `:635`, `:648`, `:678` all run
`bash "$SCORE_ARTIFACTS" run-dir > out-dimN.json 2>/dev/null` with no rc capture and then
`jq -r ... 2>/dev/null`. A crashed scorer produces an empty file, an empty `dN`, and a failure
message reading `dimension 2 scored , expected the hand-computed value 50` with the scorer's own
stderr thrown away. Because each site asserts a literal expected value (50 / 100 / 0 / 80), a
crash does *fail* -- the residual is diagnosis, not a false pass. The same file demonstrates the
right shape at `:548-554` (rc captured on the same statement) and `:563` (`jq -e` with an `ERR`
sentinel) and does not apply either here.

**Fix:** capture rc on the same statement at all four sites and interpolate the captured stderr
into the failure message.

### L4-05 [P2] CA-405 residual -- `:2547` is a presence-only meta-assertion over test scaffolding

`t44_check_uses="$(printf '%s\n' "$t44_block" | grep -c 'check_fails\|check "' || true)"` with a
`-gt 0` threshold. It asserts that T44's block contains at least one harness call -- true if 39
of 40 assertions were deleted. It also counts lines, not occurrences, though at a zero threshold
that is immaterial. The other two CA-405 sub-items are false alarms (see Noted).

**Fix:** either drop the assertion (T44's real cases already prove harness use by running) or
pin an exact expected count derived from the block.

### L4-06 [P2] CA-312 residual -- the site both fix comments cite as the "already-correct" model is still a substring match

`wave6-smoke.sh:203` is `check "required_gates_for_mode(standard, standard, none-skipped) = all 3
gates" "1 2 3" "$gates_out"`. `check()` (`_harness.sh:27-34`) is a substring match. The three
sibling sites were correctly converted to exact equality (`:213`, `:223`, `:238`), but their fix
comments at `:210` and `:221` both say *"Asserted as exact string equality instead, matching
:203's own already-correct shape"* -- and `:203` is not exact equality. A contributor copying
"the correct shape" from the cited line copies a substring match, reopening the exact class
CA-312 closed.

**Fix:** convert `:203` to `[[ "$gates_out" == "1 2 3 " ]]` and correct the two comments.

### L4-07 [P1] NEW -- `--accept-p2-debt`'s entire safety guard has zero tests

`bin/edm-state:2178` gates the new convergence override on
`[[ $conv_ec -eq 1 && $accept_p2_debt -eq 1 && "$conv_out" == "not converged: "* ]]`. The comment
at `:2171-2176` states the property that makes the feature safe: *"Deliberately narrow: only the
genuine 'blocking findings remain' refusal qualifies -- not a partial/unknown round type, invalid
JSONL, or invalid status lines, all of which also exit 1 from cmd_audit_converged but say nothing
about severity and must not be silently bypassed by this flag."*

`wave6-smoke.sh:657-745` is the complete test coverage for this feature (landed in dc8a24f, two
commits ago). It covers: P1-open refusal, the success path plus the three debt state fields, the
HANDOFF row, archive-immediately, and archive-refuses-stale-debt. It contains **no** case where
`--accept-p2-debt` is passed against a `partial` round, invalid JSONL, or an invalid status line.
The string-prefix guard on `"not converged: "` is the only thing preventing `--accept-p2-debt`
from converging a partial round -- documented as "never convergent" in `CLAUDE.md` -- and nothing
asserts it. The two usage `die()` arms at `edm-state:2090` (unrecognized third argument) and
`:2092` (`--accept-p2-debt` on a non-code-audit gate) are also untested.

**Fix:** add three cases to `wave6-smoke.sh`'s T-EDMV4 block: (a) `audit-round-start --lenses L1`
then `--accept-p2-debt` must still refuse (partial round is not a severity refusal); (b) a
malformed `findings-ledger.jsonl` with `--accept-p2-debt` must still refuse; (c) `check_fails`
on `approve-gate <PFX> 2 --accept-p2-debt` naming "only applies to the code-audit gate".

### L4-08 [P2] NEW -- exit-code assertions use a substring match, so many non-zero codes pass

`wave7-smoke.sh:2480`, `:4474`, `:4495` all use the shape
`check "... exits 0" "0" "$..._rc"`. `check()` is substring containment, so any exit code whose
decimal representation contains the digit `0` passes: 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
101, 102, ... A `timing.sh --session-start` that exited 10, or a `--generate-fixture` that exited
100, is reported as "exits 0".

**Fix:** `[[ "$t67_ss_rc" -eq 0 ]] && pass ... || fail ...` at all three sites.

### L4-09 [P2] NEW -- nine conditional SKIP paths increment no counter and are invisible to the aggregator

Each of `wave7-smoke.sh:6589`, `:7055`, `:7085`, `:7245`, `:7275`, `:7303`, `:7580`, `:7649`,
`:7737` prints `  SKIP: ...` and increments neither `PASS` nor `FAIL`. The suite's summary at
`:7954` is `Results: ${PASS} passed, ${FAIL} failed` -- no skip term -- and `run-all.sh:108`
parses exactly `^Results: [0-9]+ passed, [0-9]+ failed`. A skipped case is therefore
indistinguishable from a case that never existed.

This is not hypothetical: three of the nine (`:6589`, `:7649`, `:7737`) are gated on `command -v
flock`, and macOS -- the documented primary development platform (`CLAUDE.md`, "Testing
changes") -- ships no `flock(1)`. On a developer's own machine the G12/CA-345 lock-contention
hook contract, the G49 live-timeout case, and the G13/CA-347 unremovable-marker case never
execute, and `run-all.sh` still prints `ALL SUITES PASSED`. Two more (`:7055`, `:7085`) vanish
under root, which is the default user in most container images.

**Fix:** add `SKIP=0` and a `skip()` function to `_harness.sh`, call it at all nine sites, emit
`Results: N passed, M failed, S skipped`, and extend `run-all.sh`'s summary regex and table to
carry a SKIP column so a silently degraded environment is visible in the aggregate.

### L4-10 [P2] NEW -- four assertions over a fixture the test itself wrote three lines earlier

`wave7-smoke.sh:1659-1689` (`t25_ledger_case`) writes three literal JSONL lines at `:1663-1667`,
then asserts against them: every line is valid JSON (`:1670-1675`), every `.id` matches
`^CA-[0-9]{3}$` and carries `confidence`/`lenses` (`:1677`), IDs are unique (`:1681`), and every
`.status` is in `open|fixed|noted` (`:1685`). No plugin file is read; nothing under test produces
or consumes this fixture. These four assertions cannot fail for any change to any EDM source
file -- only if `jq` itself broke. They inflate the pass count without covering anything.

The block header at `:1626-1632` explains why the synthesizer has no directly-invokable entry
point, but does not acknowledge that the resulting assertions are vacuous. Real coverage is
available and already precedented: `edm-state render-ledger` consumes exactly this file shape and
`wave6-smoke.sh:2875-2906` already drives it.

**Fix:** pipe this fixture through `edm-state render-ledger` and assert the rendered markdown
(ID ordering, severity grouping, status rendering), converting four tautologies into real
assertions about shipped code.

### L4-11 [P2] NEW -- an unused variable is the contaminant in the T42 AC4 scan

`wave7-smoke.sh:2001` defines `MERMAID_QUOTED='CLAUDE.md Sec."Mermaid diagram conventions"'`.
Grepping the whole tree finds exactly one occurrence of the identifier: its own definition. It
has no readers. Its only observable effect is that its literal value is precisely what the
repo-wide scan 43 lines below (`:2044`, `:2045`, scanning `${PLUGIN_DIR}/`) searches for --
making it a guaranteed self-hit inside both the `t42_ac4_raw >= 11` floor and the
`t42_ac4_forms == 1` distinct-form count.

**Fix:** delete `:2001`. This is the concrete, one-line core of L4-02's self-match half.

### L4-12 [P2] NEW -- a six-arm detection regex is proven by a control exercising one arm

`wave7-smoke.sh:951` defines
`T61_BASH4_RE='declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}'`
-- six alternation arms guarding the bash-3.2 compatibility constraint. Its positive control at
`:963` is `printf '%s\n' 'declare -A foo' | grep -cE "$T61_BASH4_RE"`, which exercises only the
first arm. The `${x^^}`, `${x,,}` and `{fd}` arms carry non-trivial escaping (`\$\{`, `\^\^`,
`\{fd\}`) that no control validates; if any of them were mis-escaped, `:967`'s "zero bash-4-only
constructs found" would stay permanently green over a live violation while the control still
passes on `declare -A`.

This is adjacent to CA-403 but a distinct axis: CA-403 is about control *provenance*, this is
about control *arm coverage*.

**Fix:** loop the control over one synthetic line per arm and require every arm to match its own
line, failing by arm name.

## Noted / Not Actionable

- **CA-311 -- FIXED.** `wave7-smoke.sh:4446-4447` runs `bash "$TIMING_SH" --self-test` with rc
  captured on the same statement; `:4448` asserts exit 0; `:4450-4459` assert each of the five
  `self-test PASS:` lines individually; `:4463` pins the `self-test: PASS (5/5` denominator.
- **CA-346 -- FIXED.** Case C exists at `wave7-smoke.sh:6500-6520`, inside the five-matcher loop:
  a stub `edm-state` whose `gate-check` exits 0, asserting the hook exits 0.
- **CA-350 -- FIXED.** `wave7-smoke.sh:4335` is `grep -rn` (no `-i`), with the rationale recorded
  at `:4341-4347`; the required case-axis positive control landed at `:4364-4374` using the
  mixed-case literal `Double-Check your own work` for both pattern and seed.
- **CA-361 -- FIXED.** `wave7-smoke.sh:7940` and `:7948` both use `count_matches`.
- **CA-312 core -- FIXED.** The three sibling sites `wave6-smoke.sh:213`, `:223`, `:238` are exact
  string equality. Only the reference site is residual (L4-06).
- **CA-404 determinism half -- FIXED.** `wave7-smoke.sh:548-554` captures `rc_a`/`rc_b` on their
  own statements and asserts both are 0 before the `diff -q` at `:556`; `:563-580` additionally
  require 5 dimensions and non-null scores for dimensions 1-4. Two identically-empty crashed
  outputs now fail three assertions before reaching the diff.
- **CA-405 `:1710` -- false alarm.** The pattern is `'^- \`'`, anchored at line start, so at most
  one match per line: `grep -c` and an occurrence count are identical here. No off-by-one exists.
- **CA-405 `:1718` -- false alarm on its own terms.** `grep -ci 'defer'` is unanchored and
  case-insensitive, but the threshold is `-eq 0`. Over-matching can only produce a false
  *failure*, never a false pass, and the finding itself concedes this is "conservative for an
  absence check". `$SYNTHESIZER_AGENT`'s existence is proven by the neighbouring positive
  assertion at `:1721`.
- **CA-402 `:2768` / `:2824` -- already handled.** Both build their needles from two runtime
  halves (`:2766-2767`, `:2822-2823`) so the contiguous phrase never appears in this file's own
  source and cannot self-match, with the rationale recorded at `:2763-2765` and `:2817-2821`.
  The self-match half of CA-402 is live only at `:2044`/`:2045`.
- **`--accept-p2-debt` P0 arm -- transitively covered.** `wave6-smoke.sh:662-674` tests only the
  open-P1 refusal, but `bin/edm-state:1496` computes P0/P1/P2 from one shared `BLOCKING_FILTER`
  through one `_audit_ledger_breakdown` helper, and the override checks both counters in a single
  condition. A dedicated P0 case would be redundant; the untested branches are the non-severity
  ones (L4-07).
