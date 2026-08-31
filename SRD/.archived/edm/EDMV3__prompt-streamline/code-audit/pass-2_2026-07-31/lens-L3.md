# Code Audit Lens L3: Edge Cases & Concurrency

- **Date**: 2026-07-31
- **Round**: pass-2 (full, 11 lenses)
- **Branch**: `edm/edmv3-prompt-streamline`
- **Method**: every L3-tagged round-1 finding re-checked against the current tree at its cited
  site (line numbers below are current, not round-1 numbers), followed by a fresh pass over
  `bin/edm-state`, `bin/_edm-lint-lib.sh`, `bin/edm-lint-artifacts`, `hooks/hooks.json`,
  `.gitignore` and the eval/CI sites L3 owns.
- **Runtime limitation**: this agent had no Bash tool, so every verdict below is static reading.
  Two verdicts are flagged `medium` confidence for that reason and say why.

## Verdicts on round-1 L3 findings

| ID | Round-1 sev | Verdict | Evidence |
|---|---|---|---|
| CA-008 | P1 | **fixed** | `bin/edm-lint-artifacts:299` now reads two fields (`while IFS=: read -r lineno _rest`), matching the three sibling readers at `:285`, `:312`, `:330`. `_f` is gone. |
| CA-011 | P1 | **open (partially fixed)** | see below |
| CA-015 | P1 | **fixed** | see below |
| CA-025 | P1 | **open (P1 halves fixed, P2 residual)** | see below |
| CA-026 | P1 | **open (partially fixed)** | see below |
| CA-027 | P1 | **open (atomicity fixed, notes fidelity not)** | see below |
| CA-028 | P1 | **fixed** | see below |
| CA-055 | P2 | **fixed** | see below |
| CA-056 | P2 | **open** | see below |
| CA-057 | P2 | **fixed** | see below |
| CA-058 | P2 | **open (partially fixed)** | see below |
| CA-059 | P2 | **open (3 of 4 sub-parts fixed)** | see below |
| CA-060 | P2 | **fixed** | see below |
| CA-061 | P2 | **open (partially fixed)** | see below |
| CA-062 | P2 | **fixed** | see below |
| CA-063 | P2 | **fixed** | `.gitlab-ci.yml:521` now declares `timeout: 150m` on `eval:nightly`, above 3 x 2700s (135m) plus provisioning. The relation the finding asked for now holds. |
| CA-064 | P2 | **open** | see below |
| CA-007 | P1 | **not re-verified by L3 this round** | see "Not re-verified" |
| CA-029 | P1 (L5) | **fixed** (re-verified at L3's request) | `.gitignore:10-11` now reads `SRD/**/.edm-state.lock` and `SRD/**/.edm-state.lockd/`, which is exactly what `with_state_lock` derives from `lockbase="${f%.json}"` (`bin/edm-state:817-818`). `.gitignore:13-14` additionally covers `plugins/edm/docs/audit-patterns/*.lock` / `*.lockd/`, which is what the new CA-055 lock at `bin/edm-state:3790` creates from `${pattern_file%.md}`; `:12`, `:15` and `:16` cover every `write_atomic` temp (`.edm-state.json.tmp.*`, `audit-patterns/*.tmp.*`, `SRD/**/*.md.tmp.*`). The patterns now match what the code creates. The finding's second half -- the flock file is never unlinked -- is still true (`bin/edm-state:830` has no `rm -f "${lockfile}"`), but it is now ignored rather than untracked litter, which is what L5 asked for. |

---

## Findings (L3: Edge Cases & Concurrency)

### CA-025 (P2 residual, was P1) -- lock branches still disagree on subshell semantics

**Status**: open, downgraded. The two P1-grade halves landed.

**Fixed and verified**: staleness detection now runs on *every* failed `mkdir`, not only after the
retry budget -- `bin/edm-state:836-850` reads the pidfile, rejects a non-numeric holder
(`:840-843`), `kill -0`s a numeric one (`:845-849`), prints a named `removing stale state lock`
line and `rm -rf`s. A SIGKILLed run no longer bricks later mutations. The unconditional
`trap - EXIT INT TERM HUP` is gone: `:858-861` saves each disposition and `:866-869` restores it
through the new `_restore_trap` helper at `:466-473`.

**Still open**: the flock branch runs `"$@"` inside `( ... ) 200>"${lockfile}"` at
`bin/edm-state:830`; the mkdir branch runs it in the current shell at `:863`. The prescription was
"make both branches agree". Nothing in the tree documents the divergence, and the helper's own
docstring (`:811-814`) describes one contract for both. Every current locked body communicates by
stdout or exit status, so there is no live defect -- this is a trap laid for the next locked
helper, which will work on macOS and silently return nothing on Linux.

**Fix**: either run the mkdir branch's `"$@"` in a subshell too, or state in the docstring that a
locked body must not set variables in the caller and add a smoke assertion for it.

---

### CA-026 (P2 residual, was P1) -- checkpoint sweep is guarded but still abortable

**Status**: open, partially fixed.

**Fixed and verified**: `cmd_checkpoint` now guards all three ways round 1 asked for --
`bin/edm-state:1743` (`[[ -f "$state" ]]` with a named skip), `:1744-1747` (`jq -e '.'` validity,
so a merge-conflicted file is skipped, not parsed), `:1750` (`.prefix // empty` with a non-empty
check). The `SRD/unknown/` case is closed.

**Still open**: the third clause of the prescription -- "wrap the per-initiative body so one bad
initiative cannot abort the sweep" -- did not land. Under `set -euo pipefail` (`:54`):

- `rmw_state "$prefix" '.last_updated = $t'` at `:1752` is a bare simple command. A `jq` failure
  returns 1 (`_rmw_state_body:530`) and terminates the sweep; a flock timeout calls `die`
  (`:831`) and `exit`s the process outright.
- `write_handoff_internal "$prefix"` at `:1797` can `die` on a `write_atomic` failure (`:4188`).

Either kills every *later* initiative's checkpoint, and both hook call sites end in `|| true`
(`hooks/hooks.json:96`, `:106`), so it is invisible.

A second residual in the same loop: `prefix` is read from the file's own `.prefix`, then
`rmw_state` resolves `state_file_for "$prefix"` independently and `mkdir -p`s its parent
(`:542`). A state file whose `.prefix` disagrees with the directory it lives in (a copied
initiative, a hand-renamed directory) therefore still creates a stray `SRD/<other>/` directory and
then fails on the missing file -- the same shape as the original finding, reached through a
present-but-wrong prefix rather than an absent one.

**Fix**: `( ... ) || echo "checkpoint: [warn] skipping ${prefix}: exit $?" >&2` around the
per-initiative body, and assert `state_file_for "$prefix"` resolves to the `$state` being iterated
before mutating.

---

### CA-027 (P1) -- HANDOFF.md is now atomic, but the Notes block is still degraded on every rewrite

**Status**: open, partially fixed.

**Fixed and verified**: the truncate-in-place write is gone. `bin/edm-state:4188` is
`write_atomic "$handoff_path" _print_literal "$handoff_content" || die ...`, and the whole
document is rendered into a variable first (`:4090-4187`). A hook timeout can no longer leave a
truncated HANDOFF.md with the Notes gone.

**Still open, unchanged from round 1**: `bin/edm-state:4024-4025` is byte-for-byte the round-1
code --

```
    notes="$(awk '/^## Notes/{p=1;next} p && /^## /{p=0} p{print}' "$handoff_path" 2>/dev/null \
      | grep -v '^[[:space:]]*$' || true)"
```

Every blank line in user-authored Notes is deleted on each rewrite, so paragraph structure is
destroyed permanently and irrecoverably (HANDOFF.md gets no `.bak`; only `.edm-state.json` does,
at `:527`). The `p && /^## /{p=0}` clause still truncates the block at the first `## ` a user
writes inside their own notes. This runs on every Stop and PreCompact hook, for every active
initiative.

**Also still open**: the prescription said "inside `with_state_lock`". `write_handoff_internal`
takes no lock. Reading the notes at `:4024`, rendering, and replacing at `:4188` is an unlocked
read-modify-write over user-authored content: two windows checkpointing the same initiative can
lose one window's notes entirely (B read the old notes before A wrote the new ones; B's `mv`
wins).

**Fix**: preserve the block verbatim (drop the `grep -v`, terminate on the *next* known
generated heading or on EOF, not on any `## `), and wrap the read-render-write in
`with_state_lock "${state_file%.json}"`.

---

### CA-056 (P2) -- the pattern-file heading match is still fence-unaware and first-match-wins

**Status**: open, unchanged.

`grep -rn 'fence' plugins/edm/bin/edm-state` returns nothing. Both cited sites are unchanged in
substance:

- `bin/edm-state:3778` -- `if ! grep -qxF "$target_heading" "$pattern_file"` (the pre-flight).
- `bin/edm-state:3647` -- `!start && $0 == h { start = NR; next }` inside
  `pattern_insert_line_for`.

A pattern document that documents its own Append Schema inside a fenced example containing the
literal line `## Anti-Patterns` still has the first (fenced) occurrence win, so the entry is
spliced into the fenced example, the fence is unbalanced, and the four-`##`-heading contract check
in the blocking `lint:pattern-library-contract` job trips on a document `update-patterns` itself
corrupted. Nothing refuses a heading that occurs more than once.

**Fix**: as prescribed -- reuse the fence state machine (it is now a shared, sourceable function,
`build_line_classes` in `bin/_edm-lint-lib.sh`, so this is cheaper than it was in round 1),
require the match to be outside any fence, and refuse when the heading occurs more than once
outside fences.

---

### CA-058 (P2) -- `find` hardening landed; the environment-carried line sets did not

**Status**: open, partially fixed.

**Fixed and verified**: `collect_md_files` at `bin/edm-lint-artifacts:214-223` now has `-type f`
and `-print0`, and all three call sites consume it with `while IFS= read -r -d ""` (`:377`,
`:401`, `:449`). A directory or dangling symlink named `*.md`, and a filename containing a
newline, no longer reach awk. The TOCTOU-delete case is handled: `:244-251` guards `[[ ! -r ]]`
and reports an `unreadable` violation instead of propagating awk's exit 2.

**Still open**: the class-4 sets still ride in the environment and the consumer still cannot
observe failure. `bin/edm-lint-artifacts:142` is
`EDM_MERMAID_SET="$mermaid_set" EDM_MARKER_SET="$marker_set" awk ...`, and `:363` is
`done < <(mermaid_scan_awk "$file" "$mermaid_set" "$marker_set" 2>/dev/null || true)`. For a large
generated artifact that is mostly mermaid, both sets grow linearly with line count; on macOS
(`ARG_MAX` 256KB, and the environment counts against it) a sufficiently large artifact makes
`execve` return `E2BIG`, `|| true` swallows it, and class 4 silently reports zero findings on a
file that is entirely mermaid. Classes 1-3 already pass their sets as shell variables to a bash
function and do not have this exposure; the `|| true` also cannot distinguish "no findings" from
"the scan did not run".

**Fix**: pass the two sets on stdin (or through the same temp-file idiom class 1 uses for
`ATTR_PATTERN_FILE` at `:112`), and replace `|| true` with a status branch that reports
`scan-error` as a violation.

---

### CA-059 (P2) -- round number now printed inside the lock; the close-once guard still is not

**Status**: open, three of four sub-parts fixed.

**Fixed and verified**:
1. The audit round number is now produced from inside the locked body -- `_cmd_audit_round_start_body`
   at `bin/edm-state:3027-3040` performs the increment (`:3029-3038`) and then re-reads and prints
   `.count` at `:3039`, all under the single `with_state_lock` call at `:3090`. Two concurrent
   starts can no longer echo the same round.
2. The double-completion guard moved inside the lock: `_cmd_audit_round_complete_body:3099-3111`
   reads `already_completed_at` and refuses, and the whole body runs under `with_state_lock`
   at `:3164`.
3. `cmd_init` now takes the lock -- `:1371` -- and the "already exists" check is inside the locked
   body at `:1333`, returning the sentinel 10 that `:1372` maps to a clean exit.

**Still open**: `cmd_record_partial_verdict`'s `close` path is still pre-check-then-lock. It reads
the entry with an unlocked `read_state` at `bin/edm-state:3336`, evaluates
`has("closing_verdict")` at `:3339`, and only then enters `rmw_state` at `:3354` or `:3372`. Two
concurrent `close` calls both see `already_closed == false`, both take the first-closure branch,
and the second overwrites the first's closure with `{prior: <stale entry>, ...}` -- the documented
"an entry may be closed only once" invariant (CLAUDE.md's state-field table) is violated with no
`closure_history` written and no message. The comment at `:3096-3098` still describes this shape
as the model the round-complete path follows, which is no longer true and now cites a line number
(`bin/edm-state:2801`) that does not point at it.

**Fix**: move the `has("closing_verdict")` decision into the jq filter so check and write share
one lock, as `_cmd_audit_round_complete_body` now does.

---

### CA-061 (P2) -- dedup landed; `gate-check` still writes on a path documented read-only

**Status**: open, partially fixed.

**Fixed and verified**: `record_degraded_check` is now idempotent on `(check, reason)` --
`bin/edm-state:1173`, `if any($existing[]?; .check == $c and .reason == $r) then . else ...`. The
`degraded_checks` array no longer grows without bound, so `state_anomalies` no longer emits a
linearly growing stack of `ACTIVE_EXEMPTION` lines at session start.

**Still open**: the write itself. `cmd_gate_check:2707` still calls `record_degraded_check`
unconditionally for a legacy initiative, and that call still goes through `rmw_state` on *every*
invocation even when the entry already exists -- the idempotence is inside the jq filter, not in
front of it. So each of the five `UserPromptExpansion` hooks (`hooks/hooks.json:19`, `:32`, `:45`,
`:58`, `:71`) still: takes the advisory lock, writes `.edm-state.json.bak` (`:527`), mints a
`mktemp` and `mv`s a byte-identical state file. On a read-only checkout the `cp -p` at `:527` is
the command after the final `&&`, so `set -e` aborts and the hook exits non-zero -- which blocks
prompt expansion for every gated command on a legacy initiative. The `--help` block at `:31` still
advertises `gate-check` as `(read-only)`.

**Fix**: short-circuit before `rmw_state` when the `(check, reason)` pair is already recorded, or
drop the call from `gate-check` and amend the read-only contract.

---

### CA-064 (P2) -- an unparseable `run.json` still defaults to `complete: true`

**Status**: open, unchanged.

`plugins/edm/evals/score-artifacts.sh:520-521`:

```
    complete=$(jq -r 'if .complete == false then "false" else "true" end' "$run_json" 2>/dev/null)
    [[ "$complete" == "true" || "$complete" == "false" ]] || complete="true"
```

A zero-byte or malformed `run.json` makes `jq` fail, `complete` empty, and the guard on `:521`
then coerces the *unknown* case to `"true"`. `:526` does the same for the no-`run.json` case. The
value is emitted as `complete: $complete` at `:587`, and `edm-compare-eval` keys the
partial-run handshake off it -- so a truncated run is compared against the baseline, which is
precisely what the handshake exists to prevent. The prescription ("default the unparseable case to
`false`, or emit `complete: null` and refuse anything not literally `true`") was not applied.

**Fix**: `|| complete="false"` on `:521`, and the same on `:526`.

---

### CA-011 (P1) -- the commit hook still does not read the exit-code split

**Status**: open, partially mitigated.

`hooks/hooks.json:86` still runs `edm-lint-artifacts "$p" 2>&1 || { echo "[EDM] ..."; fail=1; }`
and `exit $fail`. Two of the three round-1 halves are unchanged:

- Prefixes are still derived from staged paths with no check that they resolve. A staged
  `git rm -r SRD/OLDPFX/`, a pre-plugin `SRD/LEGACY-DOCS/`, or a flat-layout file with a double
  underscore still yields a prefix with no state file, `edm-lint-artifacts` exits 2
  (`:373`, "no initiative for prefix"), and the commit is blocked on a tree with no violations.
- The hook still exits 1 on the honest violation path, so the exit-1-versus-exit-2 blocking
  semantics question round 1 asked to settle deliberately is still unsettled -- and
  `plugins/edm/CLAUDE.md`'s hooks table now asserts "any non-zero exit blocks the commit", which
  pins the unverified assumption rather than resolving it.

Mitigated: the message was reworded to cover both classes ("Fix artifact violations **or
edm-lint-artifacts setup/usage errors**"), and CLAUDE.md now documents that one line covers both,
so the *misleading-message* half is now documented-as-intentional and I am not re-filing it.

**Fix**: capture the status, branch on 1 vs 2, and derive prefixes only from paths whose state
file resolves (`edm-state resolve-dir "$p" >/dev/null 2>&1 || continue`).

---

### NEW-A (P2) -- the spliced pattern entry has no terminating newline, so it fuses with the insertion-point line

**Site**: `bin/edm-state:3699`, `:3676-3681`.

`pending_entries` is built with `pending_entries="${pending_entries}$(_render_pattern_entry ...)"`
at `:3699`. Command substitution strips trailing newlines, and `_render_pattern_entry:3673` ends
in a `printf ... '\n'` -- so the accumulated block ends with `not yet curated prose.` and no
newline. `_splice_pattern_file` then emits it with `printf '%s' "$pending_entries"` at `:3679`,
between `head -n $((insert_line - 1))` and `tail -n "+${insert_line}"`. The stub's last line is
therefore concatenated with whatever is on `insert_line`.

Consequences, in increasing severity:

- Two novel findings in one run produce `...not yet curated prose.` immediately followed by
  `### <second title>` with no separating blank line, unlike the single-entry case.
- Against the shipped documents this costs one blank line. In
  `plugins/edm/docs/audit-patterns/code-audit.md`, `## Anti-Patterns` is at `:70` and the next
  `## ` at `:103`, with `---` at `:101`, so `pattern_insert_line_for` backs up over the rule and
  the blanks and returns a *blank* line -- the stub's last line absorbs it and the `---` ends up
  directly under the blockquote.
- In the general case the function returns the line of the following `## ` heading whenever the
  target section's last content line is directly adjacent to it (no `---`, no trailing blank).
  That heading is then swallowed into the stub's prose line, the document drops to three `##`
  headings, and the blocking `lint:pattern-library-contract` job fails on a document
  `update-patterns` itself corrupted -- inside the lock, atomically, so nothing detects it at
  write time.
- The last-section case (`ins = NR + 1` at `:3651`) leaves the file with no trailing newline.

**Fix**: `printf '%s\n' "$pending_entries"` at `:3679`, and separate accumulated entries with an
explicit newline at `:3699` rather than relying on `_render_pattern_entry`'s leading `printf '\n'`.

---

### NEW-B (P2) -- stale-lock reclamation is not atomic and mis-classifies a live cross-user holder

**Site**: `bin/edm-state:836-856`.

The CA-025 fix is right in shape but the reclamation itself has four edge cases:

1. **TOCTOU on the reclaim.** A contender reads the pidfile at `:839`, decides the holder is dead
   at `:845`, and then `rm -rf "$lockdir"` at `:847`. Between the decision and the `rm`, another
   contender may already have reclaimed the lock and re-created `$lockdir` with its own live pid.
   The first contender's `rm -rf` then deletes a *live* lock, `mkdir` succeeds for it too, and two
   processes run the critical section concurrently -- the exact failure the lock exists to
   prevent, now reachable by a mechanism that did not exist before the fix.
2. **`kill -0` reports EPERM as "dead".** `kill -0 <pid>` on a live process owned by a different
   UID exits non-zero. On a CI host or a bind-mounted container where one run is root and another
   is not, a live holder is declared stale, removed, and the lock is stolen -- silently, with a
   message that says the PID "no longer running" when it does.
3. **PID reuse / PID namespaces.** The converse: a recycled PID, or a holder PID from a different
   PID namespace sharing the repo over a bind mount, makes a genuinely dead holder look alive.
   That degrades back to the original CA-025 timeout rather than corrupting anything, so it is the
   benign direction -- but it means the fix is not a guarantee.
4. **`continue` does not increment `tries`.** Both reclaim paths (`:843`, `:848`) `continue`
   without touching `tries`, so the 50-try bound at `:852` does not apply to a lock that keeps
   being reclaimed and re-taken. With `set -e` a failing `rm -rf` aborts, so this is not an
   infinite loop today, but the bound is not the bound the code reads as having.

**Fix**: make the reclaim conditional -- `mv "$lockdir" "${lockdir}.stale.$$" 2>/dev/null` and
only proceed if the rename succeeded (rename is atomic; the loser sees ENOENT and retries) -- and
treat EPERM from `kill -0` as "alive, not mine" rather than "dead". Increment `tries` on the
reclaim paths.

---

### NEW-C (P2) -- `write_atomic` nests a second trap layer inside `with_state_lock`, which this project documents as unsupported on bash 3.2

**Site**: `bin/edm-state:487-490` and `:509-511` nested inside `:858-869`; contract at
`bin/tests/_harness.sh:49-50`.

`with_state_lock`'s mkdir branch installs `trap "rm -rf '${lockdir}'" EXIT INT TERM HUP` at `:862`
and then runs the body in the *current shell* at `:863`. Every current body reaches `write_atomic`,
which saves the three dispositions with `trap -p` at `:487-489`, installs its own
`trap "_write_atomic_cleanup '$tmp'" EXIT INT TERM` at `:490`, and restores at `:509-511`. That is
a trap-composition nesting depth of two, on a deployment target that includes bash 3.2 -- and this
repository's own harness records, at `bin/tests/_harness.sh:49-50`:

> "via a trap installed before &lt;fn&gt; runs and restored afterwards, so this must not be nested
> (bash 3.2 has no reliable `trap -p` composition; keep the nesting depth at one)."

Two consequences, one certain and one conditional:

- **Certain**: for the whole duration of the write, the EXIT/INT/TERM disposition is
  `_write_atomic_cleanup`, *not* the lockdir cleanup. A signal during the `jq` render or the `mv`
  removes the temp and leaves `$lockdir` on disk. That is now survivable only because CA-025's
  staleness detection landed -- the two fixes are load-bearing for each other and nothing says so.
- **Conditional on the bash-3.2 `trap -p`-in-command-substitution behaviour the harness comment
  warns about**: if the capture at `:487-489` comes back empty, `_restore_trap` takes its `else`
  branch (`:471`) and runs `trap - EXIT`, which is exactly the unconditional disarm CA-025 was
  filed to remove -- reintroduced one call frame lower. I could not execute anything to settle
  which behaviour bash 3.2 exhibits, hence `medium` confidence; but the project has already
  written down that it does not trust this construct, and the code now depends on it twice.

**Fix**: have `write_atomic` skip trap installation when a lock trap is already active (pass a
flag, or set a `_EDM_TRAP_DEPTH` guard), or push the temp path onto a single script-level cleanup
list managed by one trap installed once. Whichever is chosen, add the bash-3.2 assertion the
harness comment implies is missing.

---

### NEW-D (P2) -- INT/TERM trap handlers clean up and then let execution continue

**Site**: `bin/edm-state:862`, `:490`.

Neither handler terminates. `trap "rm -rf '${lockdir}'" EXIT INT TERM HUP` and
`trap "_write_atomic_cleanup '$tmp'" EXIT INT TERM` run their command and then resume the
interrupted script. So:

- A SIGINT delivered inside the critical section **releases the lock and keeps running the
  critical section**. Another process can acquire the lock immediately and interleave with a
  read-modify-write that still believes it is exclusive. The trailing `rm -rf "$lockdir"` at `:865`
  then removes whatever lock the *other* process has since taken.
- A SIGINT inside `write_atomic` deletes `$tmp` while the redirect still holds the fd; the render
  keeps writing to an unlinked inode and `mv -f "$tmp" "$dest"` at `:500` then fails, which is
  caught -- so this half fails safe, but only by accident of the `mv` check.

Ctrl-C on a running `/edm:code-audit` or `/edm:implement` step is an entirely ordinary event, so
this is reachable without an unusual scenario.

**Fix**: `trap 'rm -rf "$lockdir"; exit 130' INT` / `exit 143` for TERM (separate the EXIT arm,
which must not `exit`), and the same shape in `write_atomic`.

---

### NEW-E (P2) -- an ignore marker on the line before a fence opener inverts fence state for the rest of the file

**Site**: `bin/_edm-lint-lib.sh:20-25` against `:33-49`.

`build_line_classes` handles a pending single-line ignore first:

```
      if (ignore_next == 1) {
        print lineno "\tignored"
        print lineno "\tmarker"
        ignore_next = 0
        next
      }
```

The `next` means the suppressed line is never examined by the fence-open branch at `:33`. So an
author who writes `<!-- edm-lint-ignore -->` immediately above a fence opener -- the documented way
to suppress "the NEXT line only" (`bin/edm-lint-artifacts:38`) -- consumes the opener. `in_fence`
stays 0, so:

- the entire fenced body is scanned as prose (false positives for `unicode`, `attribution` and
  `leaked-tool-tag` on legitimate fenced content), and
- the fence's **closing** line is then matched by the opener branch (`run_len >= 3`, `in_fence == 0`),
  so everything from the end of that fence to the next fence marker is marked `ignored` -- the
  suppression inverts, and a real violation in following prose is silently dropped.

The `END` reconciliation added for CA-057 (`:72-76`) does not catch it: the state machine ends
balanced, it is just off by one fence.

**Fix**: run the fence-open/close detection *before* the `ignore_next` consumption, or set
`ignore_next = 0` and fall through rather than `next`ing.

---

## Noted / Not Actionable

- **`write_atomic` itself (`bin/edm-state:479-512`)** -- correct in shape: `mktemp
  "${dest}.tmp.XXXXXX"` (no `$$`), directory-existence and directory-writability checks at
  `:484-485` (the *directory*, which is what CA-015 asked for, and `cmd_update_patterns:3766` now
  tests `pattern_dir` too), temp removed and status returned on both the render and the `mv`
  failure paths. CA-015's four hand-rolled sites are all routed through it (`:528`, `:1337`,
  `:3007`, `:3712`, `:4188`). Confirmed fixed; the residuals are filed as NEW-C and NEW-D.
- **`git_aware_mv` (`bin/edm-state:553-566`)** -- CA-062 fixed: `[[ ! -e "$d" ]] || die` at `:555`
  closes the nested-`SRD/.archived/PFX/PFX/` case, and a `git mv` failure on a tracked path is now
  fatal at `:559` instead of falling through to a semantics-changing `mv`.
- **`get_session_tokens_since` (`bin/edm-state:274-350`)** -- CA-060 fixed: both branches are now
  `jq -Rn` with `reduce inputs` and `fromjson?`, so one torn line costs one message
  (`:302-305`, `:332-335`), and `attribution_mode: "unparseable"` is emitted (`:317`, `:347`) so
  the silent `unknown` arm no longer absorbs it. The per-file cap is fixed differently but validly:
  `cat ...*.jsonl | tail -n "$_token_read_cap"` at `:327` caps the *concatenation*. Two residuals
  are too small to file: the comment at `:326` still says "Each file is independently line-capped",
  which the new code no longer does; and neither branch warns when `tail` actually clips, so a
  phase exceeding the cap still under-counts silently. Both are one-line follow-ups for L6.
- **Timestamp comparison boundary (`bin/edm-state:304`)** -- `($obj.timestamp // "") >= $since` is a
  string compare, and `2026-07-31T12:34:56.789Z` sorts *before* `2026-07-31T12:34:56Z` because
  `.` < `Z`. Messages inside the same wall-clock second as phase-start are excluded. Sub-second
  under-count; not worth a change.
- **`cmd_record_partial_verdict` open path (`bin/edm-state:3392-3404`)** -- CA-028 fixed: `:3397-3398`
  nests a closed entry under `prior` instead of replacing it, so the FAIL record the AC4 re-closure
  logic exists to preserve survives a re-open. A related invariant hole is *not* being filed as L3:
  re-opening a PASS-closed entry resets the close-once guard, because `has("closing_verdict")` at
  `:3339` only inspects the top level. It fails in the safe direction (archive stays blocked), and
  it is state-machine logic rather than concurrency -- L1's call.
- **`cmd_migrate_path` partial-failure window (`bin/edm-state:2603-2619`)** -- the directory is moved
  before the state write, with explicit rollback on both failure paths. A `die` from inside
  `rmw_state` (flock timeout) exits without rolling back, leaving the directory moved and
  `product_name` unset -- but `state_file_for` resolves by on-disk path, so the initiative is still
  found and the residue is two unset descriptive fields. Documented rollback design; not a defect.
- **`_lock_ec` handling (`bin/edm-state:829-832`)** -- `[[ $_lock_ec -eq 99 ]] && die` followed by
  `return $_lock_ec` is correct under `set -e`: a failing `[[ ]]` in a `&&` list is exempt, and the
  explicit `return` prevents the "last command is a failed test" trap. The `|| _lock_ec=$?` idiom
  keeps the subshell in a tested position so the timeout `die` is reachable. Verified positive.
- **`list_state_files` empty-glob handling (`bin/edm-state:109-120`)** -- `[[ -f "$_lsf_f" ]] || continue`
  covers the unmatched-glob literal, and `"${_lsf_seen[@]+"${_lsf_seen[@]}"}"` is the bash-3.2-safe
  empty-array expansion under `set -u`. Correct.
- **`is_ignored_line` / `report_violation` (`bin/_edm-lint-lib.sh:80-100`)** -- the empty-set
  short-circuit survives extraction into the shared library, and `report_violation`'s
  `${violations+x}` / `${VIOLATIONS+x}` probe works for both consumers because every calling loop
  uses `< <(...)` and runs in the current shell. Re-verified after the CA-050 extraction.
- **`cmd_init` "already exists" sentinel (`bin/edm-state:1333-1337`, `:1371-1377`)** -- returning 10
  from inside the lock and mapping it to exit 0 is a deliberate idempotence choice, and the
  existence check is now genuinely inside the critical section. Correct.
- **Commit-hook `staged=$(... | grep '^SRD/')` (`hooks/hooks.json:86`)** -- `grep` exiting 1 on no
  match would abort the assignment under an inherited `set -e`, blocking every commit. The hook
  string sets no `-e` of its own and the host invokes it through a plain shell, so this is latent
  rather than live. Recording it here because it is the same class as CA-007 and one `|| true`
  would close it permanently.
- **`update-patterns` idempotence and re-run behaviour** -- unchanged and still correct: the
  normalizer strips *every* trailing paren group (`:3610`), both sides run through it (`:3686`,
  `:3694`), and the whole read-dedup-insert now happens under one lock, so a re-run recomputes from
  disk and appends nothing.

## Not re-verified this round

- **CA-007** (tagged L1+L2+L3+L11). Its `.gitlab-ci.yml:327/:474/:531` and
  `evals/run-eval.sh:437-455` sites were not reached within this pass; I only confirmed the
  adjacent CA-063 fix in the same file. No L3 verdict is emitted for CA-007 -- take L1/L2/L11's.
- `evals/tiering-matrix.sh`, `bin/tests/*` beyond `_harness.sh` and greps, `edm-check-grants`,
  `edm-check-vocabulary`, `edm-check-skill-sync`, `edm-sync-canonical-sections`, `edm-init`,
  `edm-validate-prefix`, and all `skills/**` / `agents/**` prose. Same boundary as round 1.
