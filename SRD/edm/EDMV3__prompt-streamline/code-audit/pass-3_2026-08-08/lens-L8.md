# Code Audit Pass 3 -- Lens L8: Security & Portability

Scope: `plugins/edm/bin/` (all scripts incl. `bin/tests/`), `plugins/edm/evals/`, `plugins/edm/hooks/hooks.json`, `.gitlab-ci.yml`. Method: every L8-tagged open ledger entry re-read at its cited location with the data flow traced from untrusted input to sink, plus a fresh sweep for arithmetic/eval/source sinks, hardcoded absolute paths, env-var validation, fd conflicts, and trap-body injection.

## Cross-round ledger verification (L8-tagged, Status=open)

| ID | Sev | Verdict | Evidence |
|---|---|---|---|
| CA-157 | P1 | **FIXED** | `bin/edm-state:1724`, `:1784`, `:770` |
| CA-158 | P1 | **FIXED** | `bin/tests/timing.sh:34-41` |
| CA-023 | P1 | **FIXED** (residual, see L8-301) | `hooks/hooks.json:86` |
| CA-024 | P1 | **FIXED** (both halves) | `bin/edm-state:126`, `.gitlab-ci.yml:171-178` |
| CA-084 | P2 | **FIXED** | `bin/tests/timing.sh:302` |
| CA-085 | P2 | **FIXED** (both named halves; residual L8-303) | `bin/tests/wave7-smoke.sh:4064-4110` |
| CA-086 | P2 | **FIXED** | `evals/run-eval.sh:218-231` |
| CA-087 | P2 | **FIXED** | `hooks/hooks.json:19,32,45,58,71` |
| CA-088 | P2 | **FIXED** | `evals/score-artifacts.sh:431-433` |
| CA-135 | P2 | **FIXED** | `bin/edm-state:2184-2189`, `:2243` |
| CA-159 | P2 | **FIXED in `edm-state`; class survives elsewhere** (L8-300) | `bin/edm-state:565,575-578,1013,1025-1028` vs `bin/tests/_harness.sh:64` |
| CA-160 | P2 | **FIXED** | `bin/edm-state:77-78`, `:317-318`, `:2595` |
| CA-161 | P2 | **FIXED** as far as this environment permits | `.gitlab-ci.yml:22-37` + every `apk add` line |
| CA-162 | P2 | **FIXED** (residual L8-302) | `.gitlab-ci.yml:98`, `:198` |
| CA-014 | P2 | **L8 half FIXED** | `evals/tiering-matrix.sh:147` |

### CA-157 -- P1, security-critical: traced end to end, genuinely closed

The ledger names `[[ $((gated_phase + 1)) -eq "$phase" ]]` as the sink, reached from `phase-start`'s unvalidated `<phase-num>`. Full trace of the current code:

- The sink is now `bin/edm-state:774`, inside `phase_start_prerequisite_gate()`.
- Its only two callers are `cmd_phase_start` (`:1752`) and, indirectly, nothing else -- and **both entry points validate before any use**:
  - `bin/edm-state:1724` -- `[[ "$phase" =~ ^[1-6]$ ]] || die "phase-start: phase-num must be 1-6; got: $phase"`, placed at `:1724` *above* the `read_state` at `:1738` and the `phase_start_prerequisite_gate "$phase"` at `:1752`, so a refusal happens before the value reaches any sink and before any state read.
  - `bin/edm-state:1784` -- the identical guard in `cmd_phase_complete`.
- Defence in depth inside the sink function: `bin/edm-state:770` -- `phase="$(to_int "$1" 0)"` coerces before `:774`.

Swept every arithmetic context in the file (`-eq/-ne/-lt/-le/-gt/-ge`, `(( ))`, `$(( ))`) for an operand that could carry attacker data. All phase-valued operands are coerced upstream:

- `:1194` (`state_anomalies`), `:2193` (`migrate-schema`), `:2883` (`active-initiatives`), `:3152` (`session-start`) all read `current_phase` through `jq -r '(.current_phase // 0) | if type == "number" then floor else 0 end'`, which returns `0` for any string -- so the committed-state-file channel (CA-003) stays closed on every reader, not just the one that was patched.
- `schema_at_least` coerces at `:1105` via `to_int`, covering all ten `.schema_version` readers at once.
- `cmd_skip_phase` carries the same regex at `:3770`; `record-tests-added` validates `count` at `:2051`; `approve-gate` validates `gate` at `:1708`.
- `to_int` itself (`:102-107`) is a `case` glob test with no arithmetic, so it is not itself a sink.

**Verdict: CA-157 is actually fixed, not merely "changed nearby."** One hardening gap remains (L8-304 below): the fix has zero regression coverage.

### CA-159 -- fixed where filed, class survives one file away

`write_atomic` (`bin/edm-state:565`, `:575-578`) and `with_state_lock` (`:1013`, `:1025-1028`) now assign the path to `_WRITE_ATOMIC_TMP` / `_STATE_LOCKDIR` and reference it *inside* single quotes, so expansion happens at signal time. Behavioural coverage exists (`bin/tests/wave7-smoke.sh:4265-4308`, apostrophe-bearing lockbase and destination paths). The finding's `SRD_ROOT`-charset half is now moot: `SRD_ROOT` no longer reaches a trap body, so charset-validating it would buy nothing. Residual instance filed as L8-300.

### CA-161 / CA-162 -- CI supply chain

CA-161: every `apk add` is now version-pinned -- `.gitlab-ci.yml:85` (`bash=5.2.26-r0`), `:133`, `:152`, `:165`, `:191` (`shellcheck=0.10.0-r1`), `:222`, `:268`, `:325`, `:360` (`jq=1.8.1-r0 git=2.49.1-r0` for `bash:3.2`'s independent Alpine 3.22 base), `:389`, `:438`. The header at `:22-37` records the capture date and states the actual property bought ("fail loudly rather than silently drift"). The image-digest half remains the already-NOTED CA-111 placeholder.

CA-162: both sweeps now cover the previously-blind directories -- `lint:bash-syntax` at `:98` and `lint:shellcheck` at `:198` both iterate `plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh`. Residual filed as L8-302.

---

## Findings (L8: Security & Portability)

### L8-300 (P2) -- `bin/tests/_harness.sh:64`: the CA-159 trap-body interpolation class is still live, and the remediation comment cites this function as the *correct* example

**Vulnerability class:** trap-body injection / install-time interpolation of a filesystem path into shell source text.

```bash
# bin/tests/_harness.sh:63-64
dir="$(mktemp -d "${TMPDIR:-/tmp}/edm-harness.XXXXXX")" || { fail "..."; return 1; }
trap 'rm -rf "'"$dir"'"' EXIT INT TERM
```

`$dir` is spliced into the stored trap body at install time. Its sibling twelve lines below does it correctly:

```bash
# bin/tests/_harness.sh:92  (with_scratch_repo)
trap 'rm -rf "$dir"' EXIT INT TERM
```

**Exploitation scenario:** `$dir` derives from `TMPDIR`. Because the interpolated value lands inside double quotes, an apostrophe is harmless here -- but `$`, a backtick, or `"` are not. With `TMPDIR` pointing at an existing directory whose name contains `$(...)` or a backtick, the stored trap body command-substitutes at signal time, running attacker-chosen code as the test user during a Ctrl-C. Requires local control of `TMPDIR` plus a pre-created directory, so severity stays P2 -- but this is the identical construct CA-159 was filed against, in a file sourced by all seven smoke suites.

**Aggravating factor:** `bin/edm-state:563-564` names the exemplars of the correct pattern as "`edm-lint-artifacts:113`, `edm-check-grants:123`, `bin/tests/_harness.sh:66`". All three line numbers are stale (the real traps are at `edm-lint-artifacts:130` and `edm-check-grants:121`), and the `_harness.sh` citation points *into `harness_scratch_dir`* -- the one function in the file that uses the wrong form. A future maintainer following that citation is directed at the counter-example.

**Concrete fix:** change `_harness.sh:64` to the deferred-expansion form, using a dedicated variable so nesting stays visible:

```bash
_HARNESS_SCRATCH_DIR="$dir"
trap 'rm -rf "$_HARNESS_SCRATCH_DIR"' EXIT INT TERM
```

and correct the three line numbers in `bin/edm-state:563-564` to `edm-lint-artifacts:130`, `edm-check-grants:121`, `bin/tests/_harness.sh:92`.

---

### L8-301 (P2) -- `hooks/hooks.json:86`: the CA-023 fix compares a possibly-absolute `srd_root` against git's repo-relative paths, silently disabling all commit-time enforcement

**Vulnerability class:** portability / silent loss of a security control on a supported configuration.

CA-023 is genuinely fixed -- the hardcoded `^SRD/` is gone and the root is derived and passed to awk:

```
srd_root="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"; srd_root="${srd_root#./}";
... awk -v root="$srd_root" '{ rl=length(root)+1; if (substr($0,1,rl)==(root "/")) { ... } }'
```

But the left-hand side of that comparison is `git diff --cached --name-only` output, which is always **repository-relative**. Normalization is a single `${srd_root#./}`. Consequences:

1. `srd_root=/srv/shared/SRD` (an absolute path -- nothing in `plugin.json`, `CLAUDE.md`'s `userConfig` reference, or `edm-state`'s own `SRD_ROOT="${EDM_SRD_ROOT:-...}"` restricts the value to a relative one) never matches any staged path, so `prefixes` is empty, `test -z "$prefixes" && exit 0` fires, and **every** `git commit` skips artifact linting with no diagnostic. The control fails open and silently.
2. A trailing slash (`SRD/`) makes the awk comparison `substr($0,1,5)=="SRD//"`, which never matches -- same silent failure.
3. `awk -v root=...` applies escape-sequence processing to the assignment, so a backslash in the path is mangled before the comparison (the same POSIX-awk `-v` hazard `_harness.sh:285-290` already documents for regexes and works around via `ENVIRON[]`).

Note this is the *hook* path only: `edm-lint-artifacts` invoked directly with an absolute `EDM_SRD_ROOT` works fine, which is what makes the hook's divergence easy to miss.

**Concrete fix:** in the hook, normalize before comparing and fail loudly rather than open --

```sh
srd_root="${srd_root#./}"; srd_root="${srd_root%/}"
case "$srd_root" in
  /*) echo "[EDM] srd_root is absolute ($srd_root); commit-time artifact lint cannot map it to git paths -- run edm-lint-artifacts manually" >&2 ;;
esac
```

and pass the root through the environment (`root="$srd_root" awk '... ENVIRON["root"] ...'`) rather than `-v`, matching the workaround already established at `bin/tests/_harness.sh:291-298`.

---

### L8-302 (P2) -- `.gitlab-ci.yml:98`: the CA-162 glob widening pulls non-shell data files into a blocking `bash -n` sweep, and a data file now carries a prose ordering constraint to survive it

**Vulnerability class:** lint-scope error creating a load-bearing, undiscoverable coupling between a data file's line order and a blocking CI job.

`lint:bash-syntax` iterates `plugins/edm/bin/*` and excludes exactly one extension:

```
case "$f" in
  *.awk) continue ;;
esac
```

`plugins/edm/bin/` also contains `vocabulary-prohibited.txt` and `vocabulary-allowlist.txt`. Both are parsed as bash by the blocking job. The cost is already visible in-tree -- `bin/vocabulary-allowlist.txt:41-44`:

> `NOTE: this bare-trailing-"|" (whole-file allowlist) entry must not be the last data line in this file -- bash -n treats a "word|" with no right-hand side as an incomplete pipeline only when nothing follows it before EOF (T18/T41 QC finding); keep at least one "|<substring>" entry (like Class 6 below) after any bare-trailing-"|" entry.`

So the ordering of `:45` relative to `:56` is load-bearing for a blocking pipeline job, for a reason that has nothing to do with the file's actual consumer (`bin/edm-check-vocabulary`). Anyone appending a whole-file allowlist entry at the end of the file breaks `lint:bash-syntax` with an error message pointing at a `.txt` data file.

`lint:shellcheck` (`:198`) has the same glob and **no** extension filter at all, so it additionally shellchecks `edm-mermaid-rules.awk` and both `.txt` files. That one does not fail today only because `--include=SC2086,SC2046,SC2048,SC2068` filters ShellCheck's SC1xxx parse errors out of the emitted comment set -- i.e. it is silently analysing nothing on those three files, which is a second reason to exclude them explicitly rather than rely on filter behaviour.

**Concrete fix:** give both loops the same extension exclusion, and delete the prose constraint from the data file once the coupling is gone:

```
case "$f" in
  *.awk|*.txt) continue ;;
esac
```

---

### L8-303 (P2) -- `bin/tests/wave7-smoke.sh:4051`: the "no blocking job reaches the network" assertion covers 9 of the 11 blocking jobs

**Vulnerability class:** incomplete supply-chain guard -- the check that exists to keep unpinned installs and network calls out of the blocking path does not see two of the blocking jobs.

```
t67ac11_blocking_jobs="lint:bash-syntax lint:artifacts lint:grants lint:vocabulary lint:shellcheck test:smoke test:smoke-bash32 test:state-validate validate:manifest"
```

The blocking set in `.gitlab-ci.yml` is eleven jobs. Absent from this list: **`lint:file-type-ban`** (`.gitlab-ci.yml:217`, explicitly de-`allow_failure`'d by EDMV3-T57 AC10) and **`lint:pattern-library-contract`** (`:263`). `CLAUDE.md`'s own CI table lists both as "Blocking? Yes". A `curl | sh` or an unpinned `npm install -g` added to either job's `before_script` is invisible to this assertion, and CA-085's remediation made the missing-*named*-job case loud (`:4064-4066`) without noticing that two blocking jobs were never named in the first place.

**Concrete fix:** add both job names to `:4051`; better, derive the list from the pipeline file (every top-level `*:` key whose block contains no `allow_failure: true`) so the set cannot drift again, and keep the explicit missing-job failure at `:4084-4086` as the guard on that derivation.

---

### L8-304 (P2) -- CA-157's P1 guard has zero regression coverage, unlike both of its siblings

**Vulnerability class:** an unprotected security fix -- the guard can be removed by a future edit with a fully green suite.

`grep -rn 'CA-157'` over `plugins/edm/bin/tests/` returns nothing. No test anywhere asserts the refusal message `phase-num must be 1-6` for `phase-start` or `phase-complete`, and no test probes the injection (there is no analogue of the `a[$(touch ...)]` proof that `bin/edm-state:89-91` documents).

This is conspicuous because the two adjacent security remediations from the same wave both got behavioural probes:
- CA-160: `bin/tests/wave7-smoke.sh:4658-4668` runs `EDM_HUMAN_HOURLY_RATE_USD='150"; touch /tmp/edm-ca160-proof #'` and asserts both the refusal and the non-existence of the proof file.
- CA-159: `bin/tests/wave7-smoke.sh:4265-4308` exercises apostrophe-bearing lock and destination paths.

CA-157 is the higher-severity of the three (P1, arbitrary execution from a caller holding only the `Bash(edm-state *)` prefix grant, which the committed eval driver's allow-list holds at `evals/run-eval.sh:246` under `--permission-mode acceptEdits`), and it is the only one of the three with no test.

**Concrete fix:** add a case to `wave7-smoke.sh` mirroring the CA-160 shape exactly, against both entry points, using the suite's own `$TMP` for the proof path:

```bash
ca157_proof="${TMP}/edm-ca157-proof"
check_fails "CA-157 -- phase-start refuses a non-integer phase-num" "phase-num must be 1-6" \
  bash "$EDM_STATE" phase-start "$pfx" "a[\$(touch ${ca157_proof})]"
check_fails "CA-157 -- phase-complete refuses a non-integer phase-num" "phase-num must be 1-6" \
  bash "$EDM_STATE" phase-complete "$pfx" "a[\$(touch ${ca157_proof})]"
[[ ! -e "$ca157_proof" ]] || fail "CA-157 -- the arithmetic-context payload executed"
```

---

### L8-305 (P2) -- `bin/tests/wave7-smoke.sh:4659,4666,4668`: the CA-160 security probe uses a fixed `/tmp` path instead of the suite's own scratch tree

**Vulnerability class:** hardcoded shared-namespace path in a security regression test.

```bash
ca160_rate_out="$(EDM_HUMAN_HOURLY_RATE_USD='150"; touch /tmp/edm-ca160-proof #' bash "$EDM_STATE" --help 2>&1)"
...
[[ ! -e /tmp/edm-ca160-proof ]] && pass ... || { fail ...; rm -f /tmp/edm-ca160-proof; }
```

Three fixed, world-writable-directory references. Every other scratch path in this suite goes through `TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave7.XXXXXX")"` (`:22`) under a trap (`:23`); CA-045 was filed and fixed for exactly this class. Consequences: on macOS the suite ignores the per-user `TMPDIR` here alone; on a shared CI runner or a developer machine where the file already exists from an earlier interrupted run, the assertion fails spuriously and the failure reads as "the malformed rate was executed" -- a false alarm on the loudest possible message. Any local user can plant the file to redden the pipeline. The direction is fail-loud, not fail-open, which caps this at P2.

**Concrete fix:** route the proof path through `$TMP` (`ca160_proof="${TMP}/edm-ca160-proof"`) and interpolate it into the payload, so the trap at `:23` cleans it up and no two runs or two users collide.

---

## Noted / Not Actionable

1. **`flock` on fd 200 (`bin/edm-state:944`)** -- re-swept the full scope this round for fd 9 and fd 10-19 redirections and `exec <n>`: zero occurrences anywhere in `plugins/edm/`. 200 is deliberate and documented at `:936-939`. Confirms CA-123.
2. **`eval "$saved"` at `bin/edm-state:493` and `bin/tests/_harness.sh:122-124`** -- both eval only `trap -p` output, which bash emits already-quoted; this is the standard save/restore idiom and the only safe one on bash 3.2. Documented in place at `_harness.sh:119-120`.
3. **`for p in $prefixes` unquoted (`hooks/hooks.json:86`)** -- word-splitting is the intent and the values pass `grep -E '^[A-Z][A-Z0-9_-]*$'` immediately before, so no metacharacter can survive. Same reasoning already accepted as CA-117.
4. **`git add -A` in `evals/run-eval.sh:164`** -- throwaway `mktemp -d` scratch repo, never the user's tree. Already NOTED as CA-124.
5. **`run-eval.sh`'s `Bash(jq *)` / `Bash(edm-state *)` prefix grants under `acceptEdits`** -- the comment at `:218-231` now states precisely what a prefix matcher does and does not bound, gives the concrete bypass shape, and declares the posture "not a hard security boundary." Documented-as-intentional tradeoff; CA-086's substance is the comment, and the comment is now correct.
6. **Image digests are self-declared placeholders (`.gitlab-ci.yml:10-20`)** -- unchanged, authorized in the file itself with a refresh procedure. Already NOTED as CA-111.
7. **`eval:nightly` archives `plugins/edm/evals/runs/` for 30 days (`.gitlab-ci.yml:622-626`)** -- includes `raw/*.json` and `raw/*.stderr.log` from a run authenticated with the protected `ANTHROPIC_API_KEY`. Traced: the key is never echoed, `claude` does not log its environment, and `run-eval.sh` writes no credential material, so there is no evidence of secret exposure -- generic build-log visibility only. Not actionable on present evidence.
8. **`evals/tiering-matrix.sh:147` INT/TERM arms clean up without exiting** -- the CA-143 class, but confined to `--self-test`, which holds no lock and guards no shared resource. Cosmetic.
9. **`bin/tests/timing.sh:39` calls `srand()` with nothing calling `rand()`** -- vestigial residue of the CA-158 remediation that removed the `rand()` term. Harmless; dead code rather than a security issue (L2 surface).
10. **`.gitlab-ci.yml:399` `mktemp` with no trap in `test:state-validate`** -- leaks one file inside a throwaway CI container; `rm -f` on the happy path at `:420`. Resource hygiene (L5), not L8.
11. **No hardcoded absolute host paths in executable code** -- swept `plugins/edm/` for `/home/`, `/opt/`, `/var/`, `/usr/local/`, `/Users/`. The only hits are two provenance citations in `CLAUDE.md:358,366` (licence-verification records, deliberately naming the local clone inspected), the lens definition's own pattern list in `agents/edm-audit-security.md`, and the `/tmp` test paths filed above as L8-305. All `bin/` and `evals/` scripts derive their roots from `BASH_SOURCE` (`edm-state:62`, `run-eval.sh:55`, `score-artifacts.sh:109`, `_harness.sh:39-44`) and honour `${TMPDIR:-/tmp}`.
12. **Env-var validation is now complete at every startup boundary** -- `HUMAN_HOURLY_RATE_USD` (`edm-state:77-78`), `EDM_TOKEN_READ_LINE_CAP` (`:317-318`), `EDM_PRODUCT`/`EDM_DESCRIPTION` (`:241-244`), `EDM_EVAL_KEEP_RUNS` (`run-eval.sh:550-552`), and `edm-init`'s `CLAUDE_PLUGIN_OPTION_MODE`/`_COMPLIANCE_ENABLED`/`_IMPLEMENTATION_MODE` enums (`edm-init:49-60`) plus its `--product`/`--description` slug guard (`:65-70`). `SRD_ROOT`, `SRD_FILENAME` and `TICKET_PACK_DIRNAME` remain unvalidated but now reach only quoted path interpolation -- no arithmetic, `eval`, `source`, or trap-body sink -- so charset-validating them would buy nothing today. Worth a comment at `edm-state:66-68` recording that invariant so a future edit does not route one of them into a sink.
13. **`source` is never given an attacker-controlled path** -- all 15 `source` sites resolve through `"${SCRIPT_DIR}/..."` computed from `BASH_SOURCE`; none is cwd-relative or env-derived.

---

**Summary:** all fifteen L8-tagged open ledger entries are closed at their cited locations, including both P1 injection classes -- CA-157 verified by tracing `<phase-num>` from the CLI to `bin/edm-state:774` and confirming the `^[1-6]$` gate at `:1724`/`:1784` precedes every sink, with `to_int` coercion at `:770` as a second layer. Six new P2 findings: one surviving instance of the CA-159 trap-interpolation class in the shared test harness plus three stale exemplar citations pointing at it (L8-300); a fail-open path in the CA-023 hook fix on an absolute `srd_root` (L8-301); a lint-scope error from the CA-162 widening that has already forced a load-bearing ordering constraint into a data file (L8-302); a supply-chain guard covering 9 of 11 blocking jobs (L8-303); zero regression coverage on the P1 CA-157 guard (L8-304); and a fixed `/tmp` path in the CA-160 security probe (L8-305). No P0 or P1 issues found this round.
