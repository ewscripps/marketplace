# Code Audit Remediation Plan: EDM Plugin v2.0.0 (EDMV2) — Round 2

## Convergence Status

**Post-remediation closure (2026-06-10):** All 26 findings (CA-001..CA-026) were resolved in the
commits following this audit round. The cross-round ledger at
`SRD/EDMV2/code-audit/findings-ledger.md` is the authoritative record and marks all entries `fixed`
with round-resolved = 2. Convergence was reached on 2026-06-10.

---

**Round-2 snapshot (as audited 2026-06-09):** Open blocking findings (P0 + P1): **4** -- CA-001,
CA-002, CA-003, CA-004 (0 P0, 4 P1). Convergence NOT reached at time of audit. The finding details
below are the original audit record and are preserved unchanged for traceability.

## Context
- Audit date: 2026-06-09 (Round 2 — convergence pass over Round 1 at `code-audit/2026-06-08/`)
- Round type: full (L1-L11). This initiative uses **date-dir** rounds (`code-audit/2026-06-08/`,
  `code-audit/2026-06-09/`), not the `pass-N_` template.
- Audited scope: `plugins/edm-ai-development/` v2.0.0, post round-1 remediation
  (`b7e9125` + `0ae0f17` + `2f7b7fc` + `df0289c`)
- SRD: `SRD/EDMV2/srd.md`
- Ticket pack: `SRD/EDMV2/tickets/`
- Deployment target: local plugin (`claude plugin upgrade` over installed v1.3.0); pre-deployment —
  no shipped v2.0.0 state in the field
- Prior round: `SRD/EDMV2/code-audit/2026-06-08/REMEDIATION.md` (G1-G24, all remediated)
- Severity scale: canonical **P0 / P1 / P2 / NOTED** (`CLAUDE.md` Sec. "Severity vocabulary")
- Cross-round ledger: `SRD/EDMV2/code-audit/findings-ledger.md`

After dedup and the second-pass False Alarm Filter: **26 findings — 0 P0, 4 P1, 22 P2** (raw lens line
items ~38; the migrate-path defect alone was reported by 5 lenses). 10 of the 24 round-1 findings are
confirmed fully fixed; 14 are partial with residuals tracked as CA-NNN rows below.

## Findings Summary

| #      | Sev | Lens(es)              | Component                                                  | Issue |
|--------|-----|-----------------------|-----------------------------------------------------------|-------|
| CA-001 | P1  | L3+L4+L7+L9+L10 (+L1)  | `bin/edm-state:1114-1120`                                  | migrate-path post-move write bypasses lock + `.bak` + rollback (G12 regression) |
| CA-002 | P1  | L8                    | `bin/edm-state` migrate-path PREFIX; `bin/edm-init` prod/desc | path-traversal escape of `SRD_ROOT` (G7 bypass; LOCAL-only) |
| CA-003 | P1  | L9 (+L8)              | `plugin.json` + `.claude-plugin/plugin.json`              | dual manifest already diverged (T22 AC1/2; G5a) |
| CA-004 | P1  | L4                    | `bin/tests/wave5-smoke.sh`                                | no regression test for the P1 G7 path-traversal fix |
| CA-005 | P2  | L1                    | `bin/edm-state:985-986`                                   | Total Savings line still prints `0x` for $0 baseline (G8 residual) |
| CA-006 | P2  | L2+L3 (+L7)           | `bin/edm-state:347-351`                                   | flock-branch lock-timeout `die` unreachable; bare exit 99 (G13 residual) |
| CA-007 | P2  | L2                    | `bin/edm-state:293-306`                                   | `write_state`/`_write_state_body` orphaned after RMW extraction |
| CA-008 | P2  | L3                    | `bin/edm-state:491-522`                                   | `cmd_init` non-atomic unlocked `> "$f"` create (G9 residual) |
| CA-009 | P2  | L5                    | `.gitignore`; `bin/edm-state:295,314,1120`               | `.edm-state.json.tmp.$$` not gitignored / not trap-cleaned |
| CA-010 | P2  | L11 (+L9)             | `plugin.json` userConfig (3 keys)                         | `mode`/`compliance_enabled`/`implementation_mode` dead config (G5b; srd.md:1302-1303) |
| CA-011 | P2  | L7+L10                | `bin/edm-state:534-545`, `:1303-1316`                    | `cmd_list`/`cmd_session_start` hand-roll glob instead of `list_state_files` |
| CA-012 | P2  | L10                   | `bin/edm-state:780/1050`, `:794/1062`                    | coverage-table renderer duplicated AND diverged on padding (G18c) |
| CA-013 | P2  | L10                   | `bin/edm-state:1001-1005,1022,1690-1692,691,701`         | gate<->phase topology literal in 5+ spots (G18b) |
| CA-014 | P2  | L10 (+L4)             | `bin/tests/*`                                             | `_harness.sh` never created; preamble copy-pasted 4x; wave4b divergent (G18d) |
| CA-015 | P2  | L10                   | `bin/edm-state:866-868,1105-1106,1755-1763`              | `git_aware_mv` / `present_or_absent` duplication (G24) |
| CA-016 | P2  | L9                    | `skills/orchestrator/SKILL.md` (Step 1)                  | orchestrator never runs `active-initiatives`/`branch-check` (T35 AC3/4; pre-existing) |
| CA-017 | P2  | L6                    | `README.md:104-106`                                      | code-audit tree shows wrong layout (G16 item 2 residual) |
| CA-018 | P2  | L6                    | `bin/edm-state:1966`                                      | `--help` slice truncates last 5 subcommands |
| CA-019 | P2  | L7                    | `skills/audit-srd/SKILL.md:65-69,89-96`                  | divergent 3-row local severity scale (G17 residual) |
| CA-020 | P2  | L6                    | `CLAUDE.md:271`                                          | test-coverage-auditor disallowedTools doc contradicts agent (G16 item 8) |
| CA-021 | P2  | L6                    | `skills/code-audit/SKILL.md:186`                         | gate-summary says "P1/P2/P3" — contradicts canonical scale |
| CA-022 | P2  | L6                    | `agents/edm-test-contract.md:4`                          | frontmatter description omits GraphQL (G22 L6-09) |
| CA-023 | P2  | L6                    | `README.md:85`                                           | understates which commands the gate hook blocks |
| CA-024 | P2  | L6                    | `README.md:108`                                          | state-tree comment omits "mode fields" (G22 L6-11) |
| CA-025 | P2  | L6                    | `bin/edm-init:3,26`                                      | usage advertises 3 of 5 `--mode` values |
| CA-026 | P2  | L7                    | `agents/edm-audit-logic.md:55`                           | severity one-liner omits "+ NOTED" (G22 L7-04) |

---

## Detailed Findings

### CA-001 (P1, lenses L3 + L4 + L7 + L9 + L10, +L1 noted): migrate-path write bypasses lock, `.bak`, and rollback — re-opens G12

**Problem**: Round-1 G2/G3 converted every mutator to `rmw_state` (lock + re-read-inside-lock +
`cp -p .bak` + atomic temp+`mv`). `cmd_migrate_path` is the **sole** mutating command that was not
converted: the post-move state update at `bin/edm-state:1114-1120` is still the pre-G2 hand-rolled
`current="$(cat …)"` → `echo | jq` → `printf '%s\n' "$new" > "${f}.tmp.$$" && mv -f …`. It picked up
only the temp+`mv` half of the G9 fix; it takes **no `with_state_lock`** and writes **no `.bak`**.
Five lenses independently flagged this single root cause:
- **L3 / L10** — concurrency lost-update + missing backup: a `Stop`/`PreCompact` `checkpoint-if-active`
  (now locked) firing on the just-moved file between the `cat` (`:1115`) and `mv` (`:1120`) loses its
  `last_updated` write; and no `.bak` is created at the new location.
- **L9** — spec violation: T132 AC5 ("the backup runs for **every** mutating subcommand" — migrate-path
  explicitly listed) and T42 AC7 ("state writes go through the typed/locked path") are VIOLATED.
- **L4** — the wave5 migrate-path regression test (its designated net per G19/L4-08) asserts the field
  updates but **never asserts a `.bak`**, so it passes green against this defect (test blind spot).
- **L1** — noted the same line as out-of-L1-mandate but corroborating.
Confirmed live at `:1114-1120`.

**Fix**: Replace the manual block (`:1114-1120`) with the locked primitive, which restores the lock,
the `.bak`, and atomicity in one move:
```bash
  local new_state_file="${dst}/.edm-state.json"
  [[ -f "$new_state_file" ]] || die "migrate-path: state file not found after move: $new_state_file"
  rm -f "${new_state_file}.bak"   # drop stale source-carried backup
  rmw_state "$prefix" \
    '.product_name = $p | .initiative_description = $d | .last_updated = $t' \
    --arg p "$product" --arg d "$description" --arg t "$(now_utc)"
```
For full G12 rollback coverage, wrap the directory move (`:1105-1109`) so a post-move failure attempts
the reverse `mv "$dst" "$src"`, or stage the state rewrite before committing the move. (Extracting
`git_aware_mv` here closes CA-015 at the same time.)

**Verification**: Run `migrate-path` flat→product on a scratch initiative; assert
`${new_state_file}.bak` now exists, fields updated, no stale source `.bak` carried over. Concurrency:
loop `checkpoint-if-active` against the target during a migrate; assert no lost `last_updated` and the
file always parses. Add the wave5 `.bak` assertion (CA-004).

**Files affected**: `plugins/edm-ai-development/bin/edm-state` (`cmd_migrate_path`).

---

### CA-002 (P1, lens L8): path-traversal escape of `SRD_ROOT` via migrate-path PREFIX and edm-init prod/desc — re-opens G7

**Problem**: Round-1 G7 centralized a `^[A-Za-z0-9_-]+$` guard in `state_file_for`, but **two reachable
user-input → path sinks bypass it**:
1. `cmd_migrate_path` validates `--product`/`--description` (`:1090-1091`) but **never validates the
   positional `prefix`**; it builds `src="${SRD_ROOT}/${prefix}"` (`:1095`) and
   `dst="${SRD_ROOT}/${product}/${prefix}__${description}"` (`:1098`) and `git mv`/`mv`s
   (`:1106`/`:1108`). `prefix='../../tmp/victim'` relocates an arbitrary existing directory outside
   `SRD_ROOT`. migrate-path never routes `prefix` through `state_file_for`.
2. `bin/edm-init` validates `PREFIX` (`:27`) but takes `--product`/`--description` raw (`:18-19`,
   interactive `:58`) and runs `mkdir -p "${SRD_ROOT}/${PRODUCT}"` (`:50`) and
   `DIR="${SRD_ROOT}/${PRODUCT}/${PREFIX}__${DESCRIPTION}"` (`:49`); `--product '../../evil'` scaffolds
   outside `SRD_ROOT`. It then `export`s the raw values and calls `edm-state init`, where
   `state_file_for` validates only `prefix` — so the traversal propagates into the state-file path.

`git mv`/`mv`/`mkdir` operands are quoted → **no command execution** (L8 confirmed); this is
path-confinement escape only.

**Severity reasoning (P1, not P0)**: LOCAL-only. Exploitation requires the user's own session/LLM to
feed a malicious slug into a command they are already running locally — no remote vector, no privilege
boundary crossed, no code execution, fixed `.edm-state.json` filename bounding the primitive. Same
class and grade as round-1 G7.

**Fix**: Validate `prefix` at the top of `cmd_migrate_path` (before building `src`/`dst`) with the
canonical format (reuse the `state_file_for` guard or a shared `validate_prefix`). In `bin/edm-init`,
apply the same `^[a-z0-9][a-z0-9-]*$`-style guard to `PRODUCT`/`DESCRIPTION` after flag parsing and
after the interactive `read`. Defense-in-depth: also validate `EDM_PRODUCT`/`EDM_DESCRIPTION` inside
`state_file_for` where consumed (`:169-174`).

**Verification**: `migrate-path … '../../evil'`, `edm-init --product '../../evil' …`, and the
interactive description path are all rejected with a clear `die` and no directory created/moved outside
`SRD_ROOT`. Valid slugs still scaffold/migrate. Add wave5 cases for both vectors (CA-004).

**Files affected**: `plugins/edm-ai-development/bin/edm-state` (`cmd_migrate_path`),
`plugins/edm-ai-development/bin/edm-init`.

---

### CA-003 (P1, lens L9, +L8 noted): dual `plugin.json` already diverged — re-opens G5(a), violates T22 AC1/AC2

**Problem**: G5(a) required exactly one authoritative manifest ("no second copy can drift"). Both
`plugins/edm-ai-development/plugin.json` (root) and
`plugins/edm-ai-development/.claude-plugin/plugin.json` (canonical, the file `claude plugin validate`
loads) still exist as independent regular files (root is not a symlink — confirmed via Glob). They
carry the same 19-key set (so the deployment-critical half of G5 holds), but the content has **already
drifted**:
- `srd_root.description`: root says product-scoped `{srd_root}/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`;
  `.claude-plugin/plugin.json:27` still says the **stale flat** `{srd_root}/{PREFIX}/`. Because the
  canonical file is the one loaded, the **stale flat description is what the install-time prompt
  shows** — contradicting the canonical product-scoped layout documented everywhere else.
- `mode.description`, `jira_mcp_namespace.description` differ; `jira_project_key.description` uses ASCII
  `--` vs em-dash; userConfig key ordering differs.
This is exactly the T22 AC1/AC2 drift G5 set out to eliminate, now realized live.

**Fix**: Delete the root `plugin.json` (or replace it with a symlink to the canonical file if any
tooling expects a root copy), then re-sync the canonical `srd_root.description` to the product-scoped
form. Confirm `claude plugin validate` still passes (only the pre-existing CLAUDE.md-root advisory
should remain).

**Verification**: Exactly one `plugin.json` on disk (or root is a symlink);
`jq '.userConfig.srd_root.description' .claude-plugin/plugin.json` shows the product-scoped path;
`claude plugin validate plugins/edm-ai-development` passes.

**Files affected**: `plugins/edm-ai-development/plugin.json` (remove/symlink),
`plugins/edm-ai-development/.claude-plugin/plugin.json` (re-sync `srd_root` description).

---

### CA-004 (P1, lens L4): the P1 path-traversal fix (G7) has no regression test

**Problem**: G19 designated the new wave5 suite as the regression net for G1/G2/G3/G4/**G7**/G12, but
no test exercises a `..`-bearing `PREFIX` through `init`/`set` (the G7 `state_file_for` vector). The
only traversal assertions (wave5:66-73) cover migrate-path `--product`/`--description` (the G12 surface,
guarded separately) — and even those don't cover the migrate-path `PREFIX` vector (CA-002). A P1
security fix with zero coverage can be silently re-opened by any future refactor of `state_file_for`
(e.g. broadening the regex or short-circuiting it on the flat-path fast path at `:149`).

This is a P1 in its own right: a security fix that nothing guards is the highest-value test gap this
pass, and it pairs with CA-002 (the vectors that need new tests) and CA-001 (the missing `.bak`
assertion).

**Fix**: Add to wave5 (each must FAIL against pre-fix code, PASS against fixed code):
```bash
check "prefix path-traversal rejected (init)" "invalid PREFIX" \
  "$("$EDM_STATE" init '../escaped/INJ' 2>&1 || true)"
[[ ! -e "$TMP/escaped/INJ/.edm-state.json" ]] && pass "no file written outside SRD_ROOT" \
  || fail "G7 traversal wrote outside SRD_ROOT"
check "prefix slash rejected (set)" "invalid PREFIX" \
  "$("$EDM_STATE" set 'A/B' k v 2>&1 || true)"
# CA-002 vectors:
check "migrate-path PREFIX traversal rejected" "invalid PREFIX" \
  "$("$EDM_STATE" migrate-path --product edm --description demo '../../evil' 2>&1 || true)"
# CA-001 backup assertion:
[[ -f "${state_file}.bak" ]] && pass "migrate-path created .bak" \
  || fail "migrate-path did not create .bak (CA-001 regressed)"
```

**Verification**: New cases fail against current code (proving they catch the bug), pass after CA-001 /
CA-002 land. Run under `/bin/bash` (3.2) to catch portability regressions.

**Files affected**: `plugins/edm-ai-development/bin/tests/wave5-smoke.sh`.

---

### CA-005 (P2, lens L1): Total Savings line still prints `0x` for a $0 baseline — G8 residual

**Problem**: G8 added a numerator guard to the per-phase Savings row (`:975`) and the `--all` Cost Ratio
column (`:913`), but the single-initiative **Total** line (`:985-986`) still guards only the divisor
`$tc > 0`, not `$th > 0`. With the `cmd_init` default `estimated_size: "Unknown"` (so every
`human_baseline_usd == 0`), `metrics-report EDMV2` prints the per-phase rows correctly as `n/a` but the
footer as `Savings: 0x cheaper` — the same report contradicts itself, and `0x` is the inverse of the
intended message in the line a reader is most likely to quote.

**Fix**: Mirror the sibling guards at `:985-986`:
```jq
(if $tc > 0 and $th > 0 then "\(($th / $tc) | tostring | .[0:6])x cheaper" else "n/a" end)
```

**Verification**: `metrics-report <P>` with `estimated_size:"Unknown"` shows `n/a` in the footer; after
`set estimated_size Medium`, shows a real `Nx`. Covered by the new metrics test (see CA-014 note /
Rollout).

**Files affected**: `plugins/edm-ai-development/bin/edm-state` (`cmd_metrics_report`).

---

### CA-006 (P2, lenses L2 + L3, +L7 noted): flock-branch lock-timeout `die` unreachable; bare exit 99 — G13 residual

**Problem**: Under `set -euo pipefail`, the flock branch (`:347-351`) runs the lock body as a
standalone subshell `( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}"` (`:348`). Because it is not
in an `if`/`&&`/`||`/negation, a non-zero exit (99 on timeout, or `"$@"`'s status) triggers `set -e` to
abort **at line 348** — so `:349` `_lock_ec=$?`, the `:350` `die`, and `:351` `return` never run. Net:
on a flock host a lock timeout aborts with **exit 99 and no message**, whereas the mkdir branch (`:360`)
`die`s with a clear message and exit 1. G13's core safety property holds (fail-closed, no silent
no-op), so this is P2 — only the diagnostic and unified exit semantics are lost.

**Fix**: Consume the subshell status with `||` so it is exempt from `set -e`:
```bash
    local _lock_ec=0
    ( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}" || _lock_ec=$?
    [[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
    return "$_lock_ec"
```

**Verification**: On a flock (Linux) host, hold the lock >10s from another process; the blocked command
`die`s with the message and a non-zero exit (not a bare 99). macOS (mkdir) behavior unchanged.

**Files affected**: `plugins/edm-ai-development/bin/edm-state` (`with_state_lock`).

---

### CA-007 (P2, lens L2): `write_state`/`_write_state_body` orphaned after the RMW extraction

**Problem**: The G2 RMW extraction converted every mutator to `rmw_state`; `write_state` (`:298-306`)
now has **no caller** (a word-boundary search returns only its definition and two comments), and
`_write_state_body` (`:293-296`) is called only by `write_state` — transitively dead. The two paths that
don't use `rmw_state` (`cmd_init:522`, `cmd_migrate_path:1120`) write directly, not via `write_state`.
This is the same G14-class maintenance trap (an orphaned helper with no "reserved" comment) that round-1
fixed for `read_num` — `write_state` reads as the load-bearing "primary writer" by name.

**Fix**: Delete `write_state` (`:298-306`), `_write_state_body` (`:293-296`), and the orphaned T132
comment (`:291-292`) — their behavior already lives in `_rmw_state_body`. Alternatively, if retained as
a deliberate whole-document primitive, add a one-line "reserved — no current caller" comment and route
`cmd_init` through it. (Deletion is cleaner and matches the round-1 G14 resolution.)

**Verification**: `grep -nw write_state bin/edm-state` returns nothing (or only a commented-reserved
definition); all smoke tests still pass.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-008 (P2, lens L3): `cmd_init` non-atomic, unlocked `> "$f"` create — G9 residual

**Problem**: `cmd_init` writes the initial state with a direct `jq -n … > "$f"` (`:522`) — no
`with_state_lock`, no temp+`mv`. The `[[ -f "$f" ]]` guard (`:481-484`) prevents clobbering an existing
initiative, but the write is not atomic: a `kill -9`/disk-full between truncation-create and completion
leaves a zero-length/partial `.edm-state.json` with no `.bak` and no temp+rename to recover from. A
small TOCTOU window also exists between the check and the write. Low severity (creation-only,
existence-guarded), but it is the one remaining non-atomic state write besides migrate-path.

**Fix**: Write to a temp file and rename, mirroring `_rmw_state_body`:
```bash
  jq -n --arg p "$prefix" … '{ … }' > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"
```
(A fresh `init` legitimately produces no `.bak` — that part is intentional, per L4.)

**Verification**: Interrupt an `init` between temp write and `mv` (test build); confirm
`.edm-state.json` is never left truncated. Normal `init` still produces a valid file.

**Files affected**: `plugins/edm-ai-development/bin/edm-state` (`cmd_init`). (Resolving CA-009's
temp-file hygiene at the same time is natural.)

---

### CA-009 (P2, lens L5): `.edm-state.json.tmp.$$` not gitignored / not trap-cleaned — new (from G9)

**Problem**: The G9 atomic-write fix introduced `${state}.tmp.$$` temp files in three places
(`_write_state_body:295`, `_rmw_state_body:314`, `cmd_migrate_path:1120`), created in the committed
`SRD/{…}/` tree. The root `.gitignore` (`:9-11`) lists `.bak`/`.lock`/`.lockd/` but **not** `*.tmp` —
`git check-ignore .edm-state.json.tmp.41234` exits 1. No trap covers it (the only trap removes the
`.lockd`). On a failed write (jq error under `set -e`) or SIGKILL in the redirect→`mv` window, the temp
file leaks as permanent untracked noise, and the PID suffix means repeated failures **accumulate
distinct** files (unlike the bounded single `.bak`). This is the exact hygiene/git-noise problem G11 was
raised for, reintroduced by G9 on a sibling filename.

**Fix** (do both, cheap):
- Add `.edm-state.json.tmp.*` to the root `.gitignore`.
- In `_write_state_body`/`_rmw_state_body` (and the migrate-path write until CA-001 routes it through
  `rmw_state`), `rm -f "${f}.tmp.$$"` on the failure branch; extend the mkdir-path trap to cover it.

**Verification**: After a forced-failed write, `git status` shows no `.tmp.*`;
`git check-ignore .edm-state.json.tmp.1` exits 0.

**Files affected**: `/Users/darryl.porter/projects/marketplace/.gitignore`,
`plugins/edm-ai-development/bin/edm-state`.

---

### CA-010 (P2, lens L11, +L9): three userConfig keys are dead config — re-opens G5(b)

**Problem**: `mode`, `compliance_enabled`, and `implementation_mode` exist in both manifests as
install-time defaults but **no code path reads them**. The only `CLAUDE_PLUGIN_OPTION_*` reads are
`SRD_ROOT`, `SRD_FILENAME`, `TICKET_PACK_DIRNAME`, `HUMAN_HOURLY_RATE_USD`, `COMMIT_STATE_FILE`;
`cmd_init` hardcodes the seeds (`:512-515`), and the orchestrator selects these interactively. This
falsifies the SRD's three-tier precedence contract at `srd.md:1302-1303` (F-B-05 / EDMV2-102:
`per-initiative state > userConfig default > built-in default`) — the middle tier is missing. P2: no
runtime failure, but a regulated shop setting `compliance_enabled: true` at install finds it silently
inert. (`qc_shard_threshold` is **not** dead — consumed by `skills/implement` — no action.)

**Fix** (pick one):
- **Wire** (preferred for `compliance_enabled`): have `edm-init` read
  `CLAUDE_PLUGIN_OPTION_{MODE,COMPLIANCE_ENABLED,IMPLEMENTATION_MODE}`, export so `edm-state init` seeds
  the new state (mirroring `EDM_PRODUCT`/`EDM_DESCRIPTION`), and have the orchestrator pre-select that
  value as the default `AskUserQuestion` option — realizing the three-tier precedence.
- **Remove**: delete the three keys from both manifests + their CLAUDE.md/CHANGELOG references and note
  per-initiative interactive selection is the sole mechanism.

**Verification**: If wired: `CLAUDE_PLUGIN_OPTION_COMPLIANCE_ENABLED=true edm-init …` → new
`.edm-state.json` has `compliance_enabled: true`. If removed: the three keys are gone and no doc
advertises them.

**Files affected**: `plugins/edm-ai-development/.claude-plugin/plugin.json`,
`plugins/edm-ai-development/plugin.json`, and (if wiring) `bin/edm-init`, `bin/edm-state` (`cmd_init`),
`skills/orchestrator/SKILL.md`, `CLAUDE.md`/`CHANGELOG.md`.

---

### CA-011 (P2, lenses L7 + L10): `cmd_list`/`cmd_session_start` hand-roll the enumerator — G1/G18 residual

**Problem**: G1/G18 added `list_state_files()` and routed 4 of 6 enumerators through it; `cmd_list`
(`:534-545`) and `cmd_session_start` (`:1303-1316`) still inline their own dual-glob + linear-seen
dedup. The both-layout logic now lives in three places. No current bug (both holdouts use the correct
two-glob form), but the next extension of `list_state_files` will silently skip these two — the same
latent split G1 closed.

**Fix**: Replace both inline loops with `while IFS= read -r state; do … done < <(list_state_files)`;
keep `cmd_session_start`'s prefix-dedup wrapper over the helper output.

**Verification**: Flat + product-scoped initiatives; `list` and `session-start` enumerate both;
behavior identical pre/post.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-012 (P2, lens L10): coverage-table renderer duplicated AND diverged on padding — re-opens G18(c)

**Problem**: The coverage table is still rendered in both `get-coverage` (`:780`, `:794`) and
`metrics-report` (`:1050`, `:1062`) with **diverged padding** (whole-initiative pct pads 8/7/6 vs
9/8/7; one copy has a negative-clamp guard, the other doesn't). The same data aligns differently per
command. The G18(c) shared `def`/`render_coverage` was never created.

**Fix**: Extract one jq `def coverage_table` (and per-epic) or a `render_coverage` shell function called
from both commands; standardize on the clamped padding at `:1050`.

**Verification**: `get-coverage <P>` and `metrics-report <P>` render identical alignment for the same
data.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-013 (P2, lens L10): gate↔phase topology re-encoded as literals in 5+ spots — re-opens G18(b)

**Problem**: "gate 1→phase 1, 2→3, 3→5" is still scattered as literals across `:1001-1005`, `:1022`
(self-duplicated within one jq block as a number vs the `gated_phase_key` string just above), `:1690-1692`
(HANDOFF skip flags), `:691`/`:701` (drift handler). No helper was added. The upcoming "Gate 3.5"
compliance work would require lockstep edits, and the `:1001` vs `:1022` pair can silently disagree.

**Fix**: Add `gated_phase_for_gate()` (bash) and a single `def gated_phase_key` (metrics jq) deriving
the numeric form from the key; route all sites through them.

**Verification**: Gate-review times and skip-flag rendering unchanged; topology edited in one place.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-014 (P2, lens L10, +L4): test-harness preamble never extracted — re-opens G18(d)

**Problem**: G18(d) promised `bin/tests/_harness.sh`; it does not exist. All four smoke tests
(`wave3`/`wave4a`/`wave4b`/`wave5`) copy-paste `pass`/`fail`/`check`/`check_absent`, diverged into **two
incompatible families**: wave3/4a/5 use `[[ "$actual" == *"$expected"* ]]` (signature
`check <label> <expected> <actual>`); wave4b uses `grep -qF` with a reordered signature
`check <label> <pattern> <content>`. The 3rd positional arg means different things — a trap for the next
test author. Test-only (no prod impact).

**Fix**: Create `bin/tests/_harness.sh` with the shared counters/asserts/`EDM_STATE` resolution;
`source` it from all four (and any new wave); reconcile onto the glob-substring `check` contract used by
3 of 4.

**Verification**: All suites pass under `/bin/bash` (3.2) after sourcing the shared harness.

**Files affected**: `plugins/edm-ai-development/bin/tests/*.sh` (+ new `_harness.sh`).

---

### CA-015 (P2, lens L10): `git_aware_mv` / `present_or_absent` duplication — G24 residual

**Problem**: The `git mv … || mv` block is identical in `cmd_archive` (`:866-868`) and
`cmd_migrate_path` (`:1105-1106`); the `[present]/[absent]` ternary is repeated 9× verbatim
(`:1755-1763`). Maintainability-only (no divergence yet). G24 rated these "fold in if touching" — and
CA-001 touches the migrate-path move block, so extracting `git_aware_mv` is now low-effort.

**Fix**: Extract `git_aware_mv()` (both move sites) and `present_or_absent()` (the nine `s_*`
assignments).

**Verification**: archive + migrate-path behave identically; HANDOFF present/absent rendering
unchanged.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-016 (P2, lens L9): orchestrator never runs `active-initiatives`/`branch-check` — pre-existing (T35 AC3/AC4)

**Problem**: The `active-initiatives` and `branch-check` subcommands exist and are correct (G1 fixed the
former's glob), but **no skill invokes them**. Orchestrator Step 1 reads `current_phase`/`current_step`/
mode but never runs the simultaneous-initiative detection (T35 AC3: warn when >1 active) or the
branch-mismatch block (T35 AC4). **Pre-existing, not a remediation regression** — round-1 G1 scoped only
the subcommand glob. P2 (protective subcommands exist; the git-commit lint hook is a partial backstop).

**Fix**: Add to orchestrator Step 1: run `active-initiatives` (warn, naming each prefix+branch, if >1)
and `branch-check <PREFIX>` (BLOCK on non-zero). Prompt-logic change only.

**Verification**: With two active initiatives, the orchestrator warns naming both; on a branch mismatch
it blocks the phase.

**Files affected**: `plugins/edm-ai-development/skills/orchestrator/SKILL.md`.

---

### CA-017 (P2, lens L6): README code-audit tree shows wrong layout — G16 item 2 residual

**Problem**: `README.md:104-106` still shows `code-audit/ └── {YYYY-MM-DD}/`, but the skill writes and
reads `code-audit/pass-{N}_{YYYY-MM-DD}/` (`skills/code-audit/SKILL.md:17,40`; glob at
`bin/edm-state:1561`). CLAUDE.md:74 is correct; README is the lone outlier and also omits
`findings-ledger.md` and `lenses-run.txt`. (Note: this meta-audit's own date-dir artifacts are
hand-created, distinct from the skill's `pass-N_` convention — that does not change the README's error.)

**Fix**: Replace `README.md:104-106` with the CLAUDE.md:72-77 tree (including `findings-ledger.md`,
`pass-{N}_{YYYY-MM-DD}/`, `lenses-run.txt`).

**Verification**: README tree matches CLAUDE.md and `bin/edm-state:1561`.

**Files affected**: `plugins/edm-ai-development/README.md`.

---

### CA-018 (P2, lens L6): `edm-state --help` truncates the last 5 subcommands

**Problem**: The help branch runs `sed -n '2,34p' "$0"` (`:1966`), but the usage header spans lines 4-39
(36 subcommands); lines 35-39 (`resolve-dir`, `set-parent`, `add-related`, `update-patterns`, `lint`)
are cut. A likely line-shift regression from the rewrite.

**Fix**: Change to `sed -n '2,39p' "$0"` (or anchor to the usage-header block).

**Verification**: `edm-state --help` lists all 36 subcommands including `lint`.

**Files affected**: `plugins/edm-ai-development/bin/edm-state`.

---

### CA-019 (P2, lens L7): divergent 3-row severity scale in the audit-srd skill — G17 residual

**Problem**: G17 fixed the `edm-srd-auditor` *agent* to a 4-row P0/P1/P2/NOTED table + `## NOTED`
section, but `skills/audit-srd/SKILL.md:65-69` still defines a local **3-row** table (no NOTED, no
canonical reference) and its output skeleton (`:89-96`) has only `## P0/## P1/## P2`. The agent and its
driving skill now disagree on severity vocabulary for the same Phase-3 audit — the exact "divergent
local scale" CLAUDE.md forbids. (The sibling `audit-tickets` skill correctly delegates; audit-srd is the
outlier. G17's Files list named only the agent `.md` files.)

**Fix**: Replace the inline 3-row table at `audit-srd SKILL:65-69` with a pointer to the canonical scale
(or add the NOTED row), and add a `## NOTED` / "Decisions / Non-Findings" section to the output
skeleton.

**Verification**: audit-srd SKILL references the canonical 4-level scale and has a NOTED output home.

**Files affected**: `plugins/edm-ai-development/skills/audit-srd/SKILL.md`.

---

### CA-020 (P2, lens L6): CLAUDE.md disallowedTools contradicts the agent — G16 item 8 residual

**Problem**: `CLAUDE.md:271` says `edm-test-coverage-auditor` has `disallowedTools: Write, Edit,
NotebookEdit`, but the agent (`agents/edm-test-coverage-auditor.md:10-11`) allows `Write` (it must write
`test-coverage.md`) and disallows only `Edit, NotebookEdit`. The agent was fixed in round 1; CLAUDE.md
was not.

**Fix**: Change `CLAUDE.md:271` to `disallowedTools: Edit, NotebookEdit` (note Write is required).

**Verification**: CLAUDE.md matches the agent frontmatter.

**Files affected**: `plugins/edm-ai-development/CLAUDE.md`.

---

### CA-021 (P2, lens L6): code-audit SKILL gate-summary says "P1/P2/P3" — contradicts the canonical scale

**Problem**: `skills/code-audit/SKILL.md:186` instructs "Summarize: P1/P2/P3 counts…", but line 127
mandates the canonical P0/P1/P2/NOTED scale and the table at 137-144 uses it. The synthesizer emits
P0/P1/P2/NOTED, so the gate-summary instruction is self-contradictory. (This synthesis followed the
canonical scale, per the round-2 mandate.)

**Fix**: Change line 186 to "Summarize: P0/P1/P2 counts (+ NOTED count)".

**Verification**: The SKILL's gate-summary instruction matches its own canonical-scale mandate.

**Files affected**: `plugins/edm-ai-development/skills/code-audit/SKILL.md`.

---

### CA-022 (P2, lens L6): edm-test-contract frontmatter omits GraphQL — G22 L6-09 residual

**Problem**: `agents/edm-test-contract.md:4` `description:` says "OpenAPI/Swagger" with no GraphQL; the
body (`:17,35`), README, CLAUDE.md, and CHANGELOG were updated to include GraphQL. Frontmatter missed.

**Fix**: Edit line 4 to "…OpenAPI/Swagger or GraphQL schema…".

**Files affected**: `plugins/edm-ai-development/agents/edm-test-contract.md`.

---

### CA-023 (P2, lens L6): README understates which commands the gate hook blocks

**Problem**: `README.md:85` lists only `srd`, `tickets`, `implement`, but `hooks/hooks.json` registers
five matchers including `audit-srd` and `audit-tickets` (CLAUDE.md:390 lists all five).

**Fix**: Add the two audit commands, or say "the SRD/audit/ticket/implement phase commands".

**Files affected**: `plugins/edm-ai-development/README.md`.

---

### CA-024 (P2, lens L6): README state-tree comment omits "mode fields" — G22 L6-11 residual

**Problem**: `README.md:108` says "gate approvals, phase timestamps"; CLAUDE.md:85 says "…, mode fields".

**Fix**: Append ", mode fields" to `README.md:108`.

**Files affected**: `plugins/edm-ai-development/README.md`.

---

### CA-025 (P2, lens L6): edm-init usage advertises 3 of 5 `--mode` values

**Problem**: `bin/edm-init:3` and `:26` advertise `--mode standard|mini-srd|prototype`, but the
validator (`:30-33`) accepts five (`standard|mini-srd|iac|data-ml|prototype`).

**Fix**: Update lines 3 and 26 to list all five values.

**Files affected**: `plugins/edm-ai-development/bin/edm-init`.

---

### CA-026 (P2, lens L7): edm-audit-logic severity one-liner omits "+ NOTED" — G22 L7-04 residual

**Problem**: 10 of 11 `edm-audit-*` lenses write "P0/P1/P2 + NOTED"; `agents/edm-audit-logic.md:55`
writes "P0 / P1 / P2" (omits "+ NOTED"). It does still carry the `## Noted / Not Actionable` section, so
only the one-liner drifts.

**Fix**: Match the sibling wording at `:55`.

**Files affected**: `plugins/edm-ai-development/agents/edm-audit-logic.md`.

---

## Decisions / Non-Findings

Items flagged by a lens but cleared in this synthesis (re-checked against the canonical filter). Do NOT
re-investigate.

1. **L3 — `cmd_init` TOCTOU window between the `[[ -f ]]` check and write** — folded into CA-008
   (atomicity); the existence guard makes a concurrent double-`init` an unusual operator error, not a
   separate P-finding.
2. **L4 — rejection tests use `2>&1 || true` with substring match** — acceptable for negative
   assertions (matched substrings are specific `die`-message fragments); low false-positive risk. The
   two genuinely satisfiable-by-crash checks (SIZE_UNKNOWN exit-0 gate, session-start phase-0) are
   recorded as test-hardening within the CA-004/CA-014 test work, not promoted as standalone P-findings.
3. **L4 — `cmd_init` produces no `.bak`** — intentional (fresh file via `jq -n`); NOTED.
4. **L6 — "Verified May 2026" pricing label ~1 month stale** (`CLAUDE.md:225`, `edm-state:227`) —
   constants correct; below P2; NOTED (carried from round-1 G22 L6-10 demotion).
5. **L11 — two `plugin.json` files coexist (wiring view)** — byte-equivalent in key *set*; the actionable
   issue is the content *drift* (CA-003) and the *dead config* (CA-010), tracked separately. The mere
   coexistence is not an independent finding.
6. **L9 — T104/T105/T110/T134** — Should/Could/deferred features untouched by remediation; not
   regressions; NOTED (carried from round-1).
7. **`record-task-duration` reserved no-op** — documented (comment + CLAUDE.md + CHANGELOG); NOTED.
8. **`compute_cost_usd` `*sonnet*|*` catch-all; `--calibrate` upper-middle median;
   `human_cost_for_phase` `*) hours=0` arm; `cmd_checkpoint` drift `*)` arm; `state_file_for` AC6
   product-only branch** — all re-verified intentional/correct (L1/L2); NOTED.
9. **flock absent on macOS → mkdir fallback; `jq --arg`/`--argjson` not injectable; quoted
   `git mv`/`mv` (no command exec); zero bash-4 constructs** — re-verified (L8); NOTED.
10. **`set-supersedes`/`set-forked-from` validate non-empty only (vs `set-parent`/`add-related`
    validate-exists); `test-coverage` skill `sonnet/high` vs sibling `opus`** — documented asymmetries
    (L7); NOTED.

## Rollout Order

All work is **pre-deployment**; nothing is committed/pushed until the human asks. Branch off `main`.

1. **P1 first — close the blocking set:**
   - **CA-001** (migrate-path → `rmw_state` + move-rollback) and **CA-002** (validate migrate-path
     PREFIX + edm-init prod/desc) are both in the migrate-path/`edm-init` write path — land together in
     one `bin/edm-state` + `bin/edm-init` commit. Fold **CA-015** (`git_aware_mv` extraction) and the
     migrate-path half of **CA-009** (temp-file cleanup) into the same edit since they touch the same
     block.
   - **CA-003** (collapse to one `plugin.json` + re-sync `srd_root`) — standalone, deployment-critical;
     keep separate so a manifest revert doesn't drag code.
   - **CA-004** (wave5 regression tests for G7/CA-002 + migrate-path `.bak`) — lands **after** CA-001/
     CA-002 so the new tests assert fixed behavior (confirm each fails against pre-fix code first).
   These four are file-independent enough to parallelize (edm-state/edm-init vs plugin.json vs tests),
   except CA-004 must follow CA-001/CA-002.

2. **P2 batches (after P1):**
   - *State-write residuals* (one `bin/edm-state` commit): CA-005 (Total `n/a`), CA-006 (flock `die`),
     CA-007 (delete orphaned `write_state`), CA-008 (`cmd_init` atomic), CA-009 (rest), CA-011
     (enumerators), CA-012 (coverage `def`), CA-013 (gate↔phase helper), CA-018 (`--help` slice).
   - *Manifest/config*: CA-010 (wire-or-remove the 3 keys) — pairs with CA-003's manifest commit.
   - *Tests* (`bin/tests/`): CA-014 (`_harness.sh`) — lands after the state-write changes.
   - *Docs/skills/agents* (no runtime impact, batch last): CA-016, CA-017, CA-019, CA-020, CA-021,
     CA-022, CA-023, CA-024, CA-025, CA-026. Land **after** CA-003/CA-010 so doc/config text matches.

3. **Re-audit (targeted):** after fixes, re-run **L3, L4, L7, L8, L9** (the lenses that surfaced the
   open P1s) as a partial round, then a **full** round to record convergence.

## Verification Plan

```bash
# 1. Syntax + bash-3.2 portability guard (re-run after every edit)
bash -n plugins/edm-ai-development/bin/edm-state
bash -n plugins/edm-ai-development/bin/edm-init
bash -n plugins/edm-ai-development/bin/tests/*.sh
grep -nE 'mapfile|readarray|local -A|declare -A|\$\{[A-Za-z_]+\^\^?\}|\$\{[A-Za-z_]+,,?\}|&>>' \
  plugins/edm-ai-development/bin/*   # expect: no matches

# 2. Smoke tests under the host's /bin/bash (3.2) — catches portability + the new regression nets
/bin/bash plugins/edm-ai-development/bin/tests/wave3-smoke.sh
/bin/bash plugins/edm-ai-development/bin/tests/wave4a-smoke.sh
/bin/bash plugins/edm-ai-development/bin/tests/wave4b-smoke.sh
/bin/bash plugins/edm-ai-development/bin/tests/wave5-smoke.sh   # CA-004 cases must be present and pass

# 3. Manifest (CA-003 / CA-010)
claude plugin validate plugins/edm-ai-development   # only the pre-existing CLAUDE.md-root advisory
ls plugins/edm-ai-development/plugin.json plugins/edm-ai-development/.claude-plugin/plugin.json  # one file or symlink
jq -r '.userConfig.srd_root.description' plugins/edm-ai-development/.claude-plugin/plugin.json    # product-scoped

# 4. Per-fix manual smoke (scratch EDM_SRD_ROOT)
#  CA-001: migrate-path flat->product => .edm-state.json.bak present at new path; fields updated
#  CA-002: migrate-path '../../evil' and edm-init --product '../../evil' => die, nothing outside SRD_ROOT
#  CA-005: metrics-report <P> with estimated_size:Unknown => footer 'n/a' (not '0x')
#  CA-018: edm-state --help lists all 36 subcommands incl. 'lint'

# 5. Concurrency re-test (CA-001) — N concurrent checkpoints during a migrate; assert no lost write,
#    file always valid JSON, .bak present.

# 6. Re-audit: re-run lenses L3, L4, L7, L8, L9 (then a full round) to confirm the open P1s are closed.
```

## Round type note

**Round type: full (lenses L1-L11).** This round IS eligible to satisfy the convergence gate, but does
not (4 open P1). The targeted re-audit in step 6 would be a **partial** round (L3/L4/L7/L8/L9) — a
partial round cannot record convergence; a subsequent full round is required.
