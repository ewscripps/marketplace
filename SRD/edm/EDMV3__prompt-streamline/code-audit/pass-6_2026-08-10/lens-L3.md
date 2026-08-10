# Code Audit Pass 6 -- Lens L3: Edge Cases & Concurrency

**Tooling note (CA-130's class):** Write/Edit/Bash absent from this lens's delivered
runtime tool set (Read, Grep, Glob, WebFetch, WebSearch, TaskStop only). This report
was transcribed by the orchestrator from the lens agent's final message.

Round: 6
Lens: L3 (race conditions, TOCTOU, empty/null/default input crashes, timeout
interactions, partial-failure states without rollback)
Auditor tool set: Read, Grep, Glob only (no Bash) -- see Coverage caveat below.

## Coverage caveat (read first)

This lens had no Bash tool, so every finding below is derived from static reading.
No assertion was executed and suite greenness was not independently confirmed by
this lens (same gap CA-331 recorded for L4 in round 5).

Areas audited to completion:
- `plugins/edm/bin/edm-state`: `with_state_lock` (both branches), `write_atomic`,
  `_save_traps`/`_restore_traps`, `rmw_state`/`_rmw_state_body`, `state_file_for`,
  `get_session_tokens_since`, `cmd_checkpoint`, `cmd_gate_check`,
  `record_degraded_check`, `cmd_migrate_path` (+ move/rollback bodies),
  `cmd_audit_round_start`/`_complete`, `cmd_audit_converged`, `cmd_render_ledger`,
  `cmd_update_patterns` (+ splice/insert helpers), `write_handoff_internal` /
  `_write_handoff_body`, `cmd_resolve_dir`, `cmd_set_parent`, `cmd_add_related`.
- `plugins/edm/hooks/hooks.json`: all five UserPromptExpansion command hooks, the
  PreToolUse git-commit hook, SessionStart/Stop/PreCompact.

Areas NOT reached before the round closed -- report these as unaudited by L3 this
round, not as clean:
- `cmd_archive` / `_cmd_archive_move_body`
- `cmd_git_lock_check` / `_git_lock_age_seconds` / `_git_lock_age_bucket_label`
  (this is where round 5's CA-303 and CA-318 live; neither was re-verified)
- `cmd_phase_start` / `cmd_phase_complete` / `cmd_approve_gate` / `cmd_init`
- `.gitlab-ci.yml` job timeouts (CA-063's class)
- `plugins/edm/evals/run-eval.sh`, `score-artifacts.sh`, `tiering-matrix.sh`
- `plugins/edm/bin/tests/**` (test-only paths, deprioritized per the False Alarm
  Filter, but not swept)

## Prior-round L3 findings re-verified as still closed

Checked against shipped code, not from memory:

- CA-298 (P1, hooks.json:19 -- every non-zero gate-check status treated as a gate
  refusal): FIXED in the shape the finding prescribed. All five command hooks now
  read `edm-state resolve-dir "$prefix" >/dev/null 2>&1 || exit 0;` before
  `gate-check ... || exit 2`, so a missing state file degrades to exit 0 instead of
  hard-blocking. See F1 below for the residual the fix does not cover.
- CA-304 (P2, migrate-path tail): FIXED. `_cmd_migrate_path_move_body` no longer
  unlinks the destination `.lock` file and now carries a corrected rationale
  (`edm-state:3196-3205`); the rollback rename is wrapped in a fresh
  `with_state_lock` acquisition via `_cmd_migrate_path_rollback_body`
  (`edm-state:3235-3243`, called at `:3305`).
- CA-305 (P2, flock timeout marker): FIXED. Marker is now
  `"${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"` created with `mkdir` (atomic,
  refuses a pre-planted symlink) at `edm-state:1117-1120`, and the
  marker-write-failed sub-case has its own diagnostic arm at `:1125-1128` instead
  of a bare `exit 99`.
- CA-306 (P2, trap-depth guard documentation): FIXED. The guard sits above both
  acquisition branches (`edm-state:1067`), the flock branch arms
  `_EDM_TRAP_DEPTH=1` at `:1119`, and both comments now state the guard is
  process-global rather than lockbase-keyed (`:601-612`, `:1057-1066`).
- CA-059 (close-once invariant): still closed --
  `_cmd_record_partial_verdict_close_body` performs the unknown-ticket and
  already-closed decisions from a fresh read of `$f` inside the single
  `with_state_lock` acquisition (`edm-state:4188-4197`) and calls
  `_rmw_state_body` directly rather than re-entering `rmw_state`.
- CA-026 (checkpoint sweep abort): still closed -- the per-initiative body is
  subshell-isolated with a named warning at `edm-state:2254`/`:2299`, and the
  `.prefix`-vs-directory mismatch guard at `:2242-2247` still prevents the stray
  `SRD/<other-prefix>/` creation.

Not re-verified: CA-303, CA-318 (both in `cmd_git_lock_check`, unaudited this round).

## Findings (L3: Edge Cases & Concurrency)

### F1 -- P2 -- `plugins/edm/bin/edm-state:1625` (reached from `hooks/hooks.json:19,32,45,58,71`)
**`gate-check` still has a non-refusal path that exits non-zero and therefore
hard-blocks prompt expansion: the degraded-check breadcrumb write.**

CA-298's remediation closed the missing-state-file case with a `resolve-dir`
pre-probe. It did not close the case where `gate-check` itself performs a WRITE
that can fail for reasons unrelated to any gate.

`cmd_gate_check` is documented "Read-only -- never mutates state"
(`edm-state:3338`) and the five prompt-hook bodies repeat that claim ("read-only")
in their step 3. But at `edm-state:3395`, on the legacy-initiative branch (absent
`schema_version`, or `mode == "null"`), it calls
`record_degraded_check "$prefix" "gate-check:kernel-gate-enforcement" "no schema_version"`,
which falls through to `rmw_state` at `edm-state:1625` on the first invocation for
that (check, reason) pair. `rmw_state` acquires the state lock.

Trigger scenario:
1. Project has a legacy initiative (no `schema_version`) -- the exact population
   this branch exists for.
2. A Stop-hook or PreCompact-hook `checkpoint-if-active` sweep is mid-flight and
   holds `.edm-state.lockd` (mkdir branch, macOS) or `.edm-state.lock` (flock
   branch) for that initiative. `cmd_checkpoint` takes the lock once per
   initiative via `rmw_state` at `:2257` and again via `write_handoff_internal`
   at `:2298`.
3. The user submits `/edm:srd LEGACY` in the same window.
4. `record_degraded_check`'s `rmw_state` exceeds the give-up bound -- 10s on the
   flock branch (`:1120`), ~5s across 50 tries on the mkdir branch (`:1027`) --
   and `die`s with exit 1.
5. `cmd_gate_check` inherits that exit 1; the hook's `|| exit 2` converts it to a
   gate refusal and blocks the prompt with a lock-timeout diagnostic that names no
   gate.

Same class in the missing-`jq` case: `cmd_resolve_dir` (`edm-state:4411-4418`)
does NOT call `require_jq`, so the pre-probe succeeds on a host without `jq`;
`cmd_gate_check`'s `require_jq` at `:3357` then dies, and the hook blocks. Every
other hook in `hooks.json` degrades to exit 0 when a dependency is absent -- the
`SessionStart`, `Stop` and `PreCompact` hooks all end in `|| true`, and the
`PreToolUse` hook opens with two `command -v ... || exit 0` probes. These five are
still the outliers.

Why P2 and not P1: reachability requires either a legacy (schema-less) initiative
plus real lock contention exceeding the give-up bound, or a host with `edm-state`
on PATH but no `jq`. CA-298's headline case -- a fresh clone with
`commit_state_file=false` and no state file at all -- is genuinely fixed.

Fix (either is sufficient; the second is the durable one):
1. Make the breadcrumb write non-fatal to the caller: wrap the `rmw_state` call at
   `edm-state:1625` so a failure warns on stderr and returns 0, matching the two
   existing best-effort pre-checks in the same function (`:1615` idempotence,
   `:1620-1623` writability). The function's own docstring already calls itself
   "best effort" twice -- a lock timeout is the one failure mode that does not
   currently honour that.
2. Give `cmd_gate_check` a dedicated refusal status -- CA-298's own option (2) --
   so the hooks can distinguish refusal from setup error: `exit 2` only on the
   dedicated code, `exit 0` on anything else. This also lets the hooks drop the
   `resolve-dir` pre-probe and stop paying two process spawns per prompt.
   Additionally add `require_jq` to `cmd_resolve_dir`, or a `command -v jq
   >/dev/null 2>&1 || exit 0` probe to each of the five hook bodies.
3. Add an EXECUTING test case (CA-298's prescription (3) is still worth extending
   here): run a hook body against a legacy, schema-less prefix with the lock held
   by a background holder, and assert exit 0 rather than 2.

### F2 -- P2 -- `plugins/edm/bin/edm-state:3392-3397` + `:3338`
**`gate-check`'s documented read-only contract is contradicted by its own
implementation on the legacy branch, in three places at once.**

This is the documentation/consistency half of F1 and is separable from it: even
after F1's failure mode is fixed, `gate-check` still mutates `.degraded_checks`.

- `edm-state:3338` -- "Read-only -- never mutates state."
- `edm-state:1621` -- the warn-and-skip message asserts "gate-check remains
  read-only", i.e. the code is aware the contract is load-bearing but only
  preserves it on the unwritable-directory path.
- `hooks/hooks.json:23,36,49,62,75` -- all five prompt bodies instruct the model
  that `edm-state gate-check <PREFIX> <cmd>` is "(read-only; ...)".

The mutation is real and intended (EDMV3-T62 AC5 wants the skip recoverable from
state), so the defect is the three claims, not the write. This matters beyond
prose: an operator or agent reading "read-only" will run `gate-check` against a
shared initiative believing it cannot contend for the lock or dirty the working
tree, and it can do both -- `_rmw_state_body` also writes a `.bak` sibling
(`edm-state:705`).

Fix: change the three claim sites to state the actual contract -- "read-only with
respect to gate state; may additively record a one-time `.degraded_checks`
breadcrumb for a legacy initiative" -- and add a smoke assertion that the string
"read-only" does not appear unqualified in `cmd_gate_check`'s docstring or in the
five prompt bodies while `record_degraded_check` remains reachable from
`cmd_gate_check`.

### F3 -- P2 -- `plugins/edm/bin/edm-state:4705` and `:1120`
**`update-patterns` locks a path inside the installed plugin tree, creating a lock
file that is never unlinked in a directory no `.gitignore` covers.**

`cmd_update_patterns` takes its lock on the pattern document, not on initiative
state:

    new_findings="$(with_state_lock "${pattern_file%.md}" _cmd_update_patterns_body ...)"

with `pattern_file="${SCRIPT_DIR}/../docs/audit-patterns/<type>-audit.md"`
(`:4649-4658`). So the lockbase is
`plugins/edm/docs/audit-patterns/code-audit`, and:

- On the flock branch, `200>"${lockfile}"` at `:1120` creates
  `plugins/edm/docs/audit-patterns/code-audit.lock`, and CA-169's rule -- never
  unlink a flock target -- correctly leaves it on disk forever.
- CA-169's own justification for that being safe was rewritten in round 5
  (`edm-state:1083-1087`) to cite `edm-init`'s per-initiative `.gitignore`. That
  reasoning does not extend to this call site: the leaked file is not in an
  initiative directory at all, it is in the plugin's own `docs/` tree, and
  `edm-init` never writes a `.gitignore` there.

Consequence in this repository: running `/edm:code-audit`'s update-patterns step on
a Linux host (or any host with `flock(1)`) leaves up to five untracked
`*.lock` files inside `plugins/edm/docs/audit-patterns/`, which is a tracked
directory in the marketplace repo -- they surface in `git status` and in merge
requests. On the mkdir branch the `.lockd` directory is removed on the normal path
(`:1265`), so this is flock-branch-only, i.e. CI and Linux contributors.

This is adjacent to CA-314 (which covered per-initiative runtime paths) but is a
different location that CA-314's prescribed consumer `.gitignore` block does not
reach, because the path is in the plugin, not the consumer project.

Fix: either (a) move the lockbase for pattern-file mutation under `TMPDIR`, keyed
by a hash of the pattern file's absolute path -- the pattern file is
plugin-internal, so cross-host lock semantics are not required and this removes
the write from the plugin tree entirely; or (b) add
`plugins/edm/docs/audit-patterns/*.lock` and `*.lockd/` to the repository
`.gitignore` AND to whatever consumer-facing `.gitignore` guidance CA-314's fix
adds, and correct `edm-state:1083-1087` so its justification names this site too.
(a) is preferable -- it makes the claim at `:1083-1087` true by construction
rather than by a second `.gitignore` entry that the next reader has to find.

### F4 -- P2 -- `plugins/edm/bin/edm-state:3812-3865`
**`render-ledger` reads `findings-ledger.jsonl` and writes `findings-ledger.md`
with no lock on the ledger, then records the hash under a separate lock -- so two
concurrent rounds can publish a markdown render and a recorded hash that disagree.**

`cmd_render_ledger` does, in order and with no single lock spanning them:
1. `:3829-3853` -- read and render `findings-ledger.jsonl` into `$body`.
2. `:3859-3860` -- `mkdir -p` then `write_atomic "$md_path" ...`.
3. `:3864` -- `record_artifact_hash "$prefix" "findings_ledger" "<md_path>"`,
   which internally takes the state lock via `rmw_state` (`:193-196`).

Each step is individually atomic; the sequence is not. Interleaving of two
`render-ledger` calls (or one `render-ledger` against a concurrent ledger append)
yields: process A renders from ledger v1, process B renders from ledger v2, B's
`mv` lands, then A's `mv` lands, then A records the hash of what is now A's
content while B records B's -- last-hash-wins against last-content-wins
independently. The failure surfaces later as a phantom `cmd_checkpoint` drift
warning (`:2263-2295`) telling the user the ledger was hand-edited when it was
not, and the remediation that warning prescribes -- re-run the audit and
re-approve a gate -- is expensive and wrong.

This is CA-055's class (unlocked read-dedup-insert on the pattern file) at the
ledger, and unlike the pattern file the ledger genuinely has concurrent writers by
design: eleven lens agents plus a synthesizer per round.

Reachability is what caps it at P2: `render-ledger` is invoked once per round from
the code-audit skill, so two concurrent invocations require two audits converging
on one initiative -- which is the exact scenario CA-055 was filed for and fixed.

Fix: wrap steps 1-3 in a single `with_state_lock` acquisition on the ledger's own
lockbase (`"${init_dir}/code-audit/findings-ledger"`), moving the body into a
`_cmd_render_ledger_body` helper the way `_cmd_audit_round_complete_body` and
`_cmd_record_partial_verdict_close_body` are structured. Note the constraint that
makes this non-trivial and must be respected: `record_artifact_hash` calls
`rmw_state`, which calls `with_state_lock`, and the reentrancy guard at
`edm-state:1067` is PROCESS-GLOBAL, not lockbase-keyed (CA-306) -- so
`record_artifact_hash` cannot be called from inside the new locked body. Structure
it as: locked body does read + render + `write_atomic` and prints the rendered
path; `record_artifact_hash` runs after the lock is released.

### F5 -- P2 -- `plugins/edm/bin/edm-state:4622-4630`
**`update-patterns` accumulates `pending_entries` and computes the insertion point
in the right order, but a missing target heading is discovered AFTER the entries
are built and reported as `0 new findings` on stdout while stderr says "skipping"
-- so the caller records a successful zero-finding run for what was actually a
refusal.**

In `_cmd_update_patterns_body`:

    if [[ "$new_findings" -gt 0 ]]; then
      insert_line="$(pattern_insert_line_for "$pattern_file" "$target_heading")"
      if [[ -z "$insert_line" || "$insert_line" -eq 0 ]]; then
        echo "update-patterns: ... skipping (nothing appended, no end-of-file fallback)" >&2
        echo 0
        return 0
      fi
      write_atomic ...
    fi
    echo "$new_findings"

The `echo 0; return 0` branch is indistinguishable, on stdout and in exit status,
from "there were genuinely no novel findings". `cmd_update_patterns` then persists
that zero into state at `:4709-4713` as
`patterns_updates[<type>] = {updated_at: ..., new_findings: 0}` and prints
"no novel findings to append" at `:4718` -- which is false; there were N novel
findings and none was recorded anywhere.

This is a partial-failure state reported as a clean success. The state field is
the durable artifact, so the loss is permanent: a later run re-derives the same N
findings, hits the same missing heading, and records another 0, with nothing in
state ever indicating that the pattern library is N entries behind.

Note the pre-flight at `cmd_update_patterns:4693` already greps for the target
heading and returns early -- so this inner branch fires only in the narrow case
where the heading exists as plain text but `pattern_insert_line_for` rejects it
(heading only inside a fence, per CA-056's fence-awareness, since the pre-flight's
`grep -qxF` is NOT fence-aware). That divergence between a fence-unaware
pre-flight and a fence-aware insertion resolver is itself the trigger.

Fix: return a distinct non-zero status from `_cmd_update_patterns_body` on the
no-insertion-point branch and have `cmd_update_patterns` refuse loudly rather than
recording a zero -- or, better, make the `:4693` pre-flight use the same
fence-aware `pattern_insert_line_for` resolution the body uses, so the two can
never disagree about whether the heading is usable, and delete the inner branch.
Either way, do not write `new_findings: 0` into `patterns_updates` for a run that
found N and appended none.

### F6 -- P2 -- `plugins/edm/bin/edm-state:4966`
**HANDOFF.md Notes round-trip strips exactly one leading newline on write but the
capture can produce zero or two, so the blank-line normalization is not a fixed
point for a hand-edited file.**

`_write_handoff_body` captures the Notes block verbatim from the `## Notes`
heading to EOF:

    notes="$(awk '/^## Notes/{p=1;next} p{print}' "$handoff_path" ...)"
    notes="${notes#$'\n'}"

and re-emits it at `:5124-5125` as `printf '%s\n\n' "## Notes"` followed by
`printf '%s\n' "${notes}"`.

The `${notes#$'\n'}` strip assumes the captured text begins with exactly one blank
line -- true for a file this function generated. It is not true for a
hand-authored or hand-edited HANDOFF.md:

- If the user writes prose immediately after `## Notes` with no blank line, the
  capture starts with the prose, the strip is a no-op, and the render inserts its
  own blank line -- so the file gains one blank line on the first regeneration and
  is then stable. Benign.
- If the user leaves TWO blank lines after `## Notes` (ordinary when pasting a
  block), the capture begins with two newlines, one is stripped, one survives, and
  the render adds its own -- net two again. Stable, but the "strip exactly one so
  it does not grow by one on every regeneration" invariant the comment at
  `:4962-4966` claims is only established for the one-blank-line case. The comment
  states the general property; the code establishes the specific one.
- Command substitution strips ALL trailing newlines from `$(...)`, so a user's
  deliberate trailing blank lines are silently dropped on every regeneration.

CA-027 fixed the destructive half of this (the old `grep -v '^[[:space:]]*$'` pass
that deleted every blank line, and the missing lock). What remains is cosmetic and
bounded -- no unbounded growth, no content loss except trailing blanks -- which is
why this is P2 and not higher.

Fix: normalize instead of stripping a fixed count -- strip ALL leading blank lines
from `$notes` (`while [[ "$notes" == $'\n'* ]]; do notes="${notes#$'\n'}"; done`,
or an `awk` pass), so the round-trip is idempotent from any starting state, and
narrow the comment at `:4962-4966` to describe normalization rather than a
one-newline assumption.

### F7 -- P2 -- `plugins/edm/bin/edm-state:236-243`
**`state_file_for`'s multiple-match branch warns and silently picks `matches[0]`,
and "first" is glob order -- so a duplicated PREFIX resolves non-deterministically
across hosts and every downstream mutation targets a directory the operator did
not choose.**

    if [[ ${#matches[@]} -eq 1 ]]; then
      echo "${matches[0]}"; return 0
    elif [[ ${#matches[@]} -gt 1 ]]; then
      echo "edm-state: WARNING: multiple product-scoped directories for ${prefix}; using first match" >&2
      echo "${matches[0]}"; return 0
    fi

`plugins/edm/CLAUDE.md` states PREFIX is "globally unique across ALL product
subdirectories -- two products may not share a PREFIX", and `edm-validate-prefix`
enforces it at creation time. But `state_file_for` is the resolver every mutator
funnels through, and its response to the invariant being violated -- by a merge, a
`git mv`, or a hand-created directory, none of which pass through
`edm-validate-prefix` -- is to proceed against an arbitrary one of the candidates.

Why this is L3 and not merely a style question: the WARNING goes to stderr, and
essentially every consumer discards it. The five UserPromptExpansion hooks pipe
`resolve-dir` to `>/dev/null 2>&1`; the SessionStart hook is
`edm-state session-start 2>/dev/null || true`; the Stop/PreCompact hooks end in
`|| true`. So the one signal that the resolution was ambiguous is guaranteed
invisible on every automated path. The mutation then lands in whichever directory
the glob happened to enumerate first, which is locale- and filesystem-dependent,
so two developers on the same repo can have `edm-state set` write to two different
initiatives.

Contrast with the same file's own handling of the same class of ambiguity:
`pattern_insert_line_for` at `:4540-4542` `die`s outright -- "refusing to guess
which one is the real section" -- when its target heading matches more than once.
That is the correct posture and it is already the house pattern in this file.

Fix: `die` on `${#matches[@]} -gt 1`, naming every candidate path and instructing
the operator to run `edm-state migrate-path` or remove the duplicate -- mirroring
`pattern_insert_line_for`'s refusal wording. If some read-only caller genuinely
needs a best-effort answer, add an explicit opt-in flag rather than making
guess-silently the default for all ~30 mutators. Add a smoke case asserting the
refusal, since no current assertion can distinguish "picked the right one" from
"picked one".

### F8 -- P2 -- `plugins/edm/bin/edm-state:5023-5028`
**`_write_handoff_body` renders `cmd_audit_converged`'s stderr into HANDOFF.md as
the "Open Code-Audit Findings" section body, so a diagnostic about a malformed
ledger is published into a committed artifact as if it were a findings summary.**

    of_out="$(cmd_audit_converged "$prefix" 2>&1)" || of_ec=$?
    case "$of_ec" in
      0) open_findings_summary="_(${of_out})_" ;;
      1) open_findings_summary="${of_out}" ;;
      *) open_findings_summary="" ;;
    esac

Exit 1 from `cmd_audit_converged` is documented at `:4034-4035` as THREE distinct
conditions, not one: blocking findings remain, OR the latest round was
partial/unknown, OR a line carries an out-of-enum status. Only the first is a
findings summary. The other two produce, respectively:

- `:4113` -- "last round was partial (lenses: ...); a full round is required for
  convergence"
- `:4083`/`:4087-4091` -- "invalid JSONL at <path>" or "invalid status on
  finding(s) ... expected: open|fixed|noted:" followed by per-ID lines

...and all of them land verbatim under a `## Open Code-Audit Findings` heading in
a git-committed HANDOFF.md, because `2>&1` merges them into `$of_out`. A reader --
or an agent resuming from HANDOFF.md, which is the file's entire purpose -- reads
"invalid JSONL at .../findings-ledger.jsonl" as the initiative's open-findings
state.

Related, same lines: `cmd_audit_converged` calls `die` on a usage error
(`:4039`) and `read_state` dies if the state file vanished mid-run (`:544`). `die`
exits 1, so a die message would also be captured and rendered as the section body.
`_write_handoff_body` checked `-f "$state_file"` at `:4733`, but that check is in
the caller and the file could be removed between the two.

Fix: separate the streams. Capture stdout and stderr independently, render only
stdout under the findings heading, and route a non-findings exit-1 (invalid JSONL,
partial round) to a distinct, honestly-labelled row -- e.g. "- **Open findings**:
unavailable (ledger error; run `edm-state audit-converged <PREFIX>`)". Better
still, give `cmd_audit_converged` distinct exit codes for "blocking findings
remain" versus "ledger unreadable / round not full", since three callers already
branch on its status and none can currently tell those apart.

## Noted / Not Actionable

- **`_lock_timeout_marker` derived from `$$` (`edm-state:1117`)** -- `$$` is not
  unique across containers sharing a `TMPDIR`, the same objection CA-015 raised
  about `.tmp.$$`. Not actionable here: the marker lives under `TMPDIR`, which is
  per-container in every environment this runs in, and it is `rm -rf`'d
  immediately before use at `:1118` and immediately after the check at `:1123`.
  CA-305 already moved it out of the tracked tree, which was the load-bearing half.
- **mkdir branch's `rm -rf "${_dst_lockbase}.lockd"` inside the locked body
  (`edm-state:3215`)** -- this genuinely removes a LIVE lockdir mid-critical-
  section on the mkdir branch, because the lockdir travelled to the destination
  with `git_aware_mv` while `with_state_lock`'s own cleanup at `:1265` still points
  at the source. But it is necessary (otherwise the lockdir is orphaned at the
  destination forever), it is documented at `:3189-3195`, and the only remaining
  work in the body after it is a marker-glob sweep that touches no state. Deliberate
  and explained; not actionable.
- **`with_state_lock` give-up bounds differ between branches (~5s mkdir vs 10s
  flock)** -- standing under CA-294, which recorded this as an undocumented
  asymmetry rather than a defect. Re-derived independently this round and reached
  the same conclusion; do not re-file.
- **`echo $$ > "$pidfile" 2>/dev/null || true` unchecked (`edm-state:1214`)** --
  standing under CA-329. A failed write here means an invalid pidfile, which the
  age-gated invalid-PID reclaim path at `:1172-1195` handles correctly.
- **`cmd_checkpoint`'s drift-detection re-read of `$state` at `:2260` is outside
  any lock** -- read-only, and its only output is an advisory warning. A torn read
  produces a spurious or missing warning, never a bad write. Consistent with the
  file's treatment of every other read-only path (`cmd_list`,
  `cmd_active_initiatives`, `cmd_session_start`, `cmd_audit_converged` -- the last
  documented "takes no lock, mutates nothing" at `:4028`).
- **`record_degraded_check`'s unlocked idempotence pre-check at `:1612-1615`** --
  a TOCTOU against a concurrent recorder, but the locked jq filter at
  `:1627-1630` re-checks `any($existing[]?; ...)`, so the write is idempotent
  regardless of the pre-check's answer. Documented at `:1594-1597` as exactly
  this. Correct as written.
- **`with_state_lock` nested inside `cmd_update_patterns` then `rmw_state`
  (`:4705` then `:4709`)** -- sequential, not nested; the pattern-file lock is
  fully released before the state lock is acquired, so the process-global
  reentrancy guard at `:1067` is not tripped. Verified by reading, not assumed.
- **`_write_handoff_body` calling `cmd_audit_converged` from inside
  `with_state_lock` (`:5023`)** -- would deadlock or trip the reentrancy guard if
  `cmd_audit_converged` took a lock. It does not: verified read-only end to end
  (`:4038-4164`, no `rmw_state`, no `with_state_lock`, no `write_atomic`). Safe as
  written -- recorded here so a future contributor does not add a lock to
  `cmd_audit_converged` without noticing this caller. The separate defect on those
  same lines is F8.
- **`get_session_tokens_since` scoped-branch fallthrough (`:383-386`)** -- `tail |
  jq ... && return 0` under `set -o pipefail` correctly falls through to the
  whole-directory branch when either stage fails, and the empty-`$_g47_capped_lines`
  case at `:413` yields a well-formed zero result because the jq program's
  `if ($line | length) == 0 then .` arm absorbs the lone blank line. Both
  empty-input paths verified safe.
- **`to_int` coercion of every externally-sourced arithmetic operand
  (`:109-114`)** -- verified still in place and still documented with the bash
  arithmetic-injection rationale at `:92-108`. This is L1/L8's territory; noted
  only to confirm the empty-string and non-numeric input cases return the default
  rather than crashing.
- **Test-only paths under `plugins/edm/bin/tests/`** -- deprioritized per the
  False Alarm Filter clause 3. Not swept this round; see the Coverage caveat.
</content>
