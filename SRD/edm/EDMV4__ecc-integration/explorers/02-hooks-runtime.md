# Explorer 02 -- Hooks and Runtime Enforcement

Scope: `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`, every `bin/` script
the hooks delegate to, and the three ECC-integration-analysis items that touch this surface:
4.1 (GateGuard), 5.3 (hookify dispatcher), 5.4 (Stop-hook completion gate).

**Repo-state caveat (applies to every finding below):** the working tree has unstaged
modifications to `plugins/edm/bin/edm-state` and `plugins/edm/CLAUDE.md`. Everything cited here is
working-tree content (the tool contract requires this), which is the right thing to plan against,
but it means: (a) an installed plugin cache running 3.2.1 may not match what is read here, and (b)
even the last-committed 3.2.0 tree may disagree with these line numbers. Cross-check line numbers
against HEAD before citing them in a ticket.

---

## 1. Current state: every hook EDM registers today

### 1.1 The real registration count -- three different numbers, all correct for what they count

`plugins/edm/docs/ecc-integration-analysis.md:46` states "EDM ... 5 hook registrations." That
number is CLAUDE.md's own **table-row** count (`plugins/edm/CLAUDE.md:690-696`, five rows), not the
JSON structure's registration count. Reading `hooks/hooks.json` directly gives two other true
counts:

| What is counted | Count | Evidence |
|---|---|---|
| Distinct top-level event keys | **6** | `hooks.json:2,13,80,91,101,111` -- `SessionStart`, `UserPromptExpansion`, `PreToolUse`, `Stop`, `PreCompact`, `SubagentStop` |
| Matcher blocks (the unit a new registration would add one of) | **10** | 1 SessionStart (`:3-11`) + 5 UserPromptExpansion matchers (`:14-78`, one each for `edm:srd`, `edm:audit-srd`, `edm:tickets`, `edm:audit-tickets`, `edm:implement`) + 1 PreToolUse (`:81-89`) + 1 Stop (`:92-99`) + 1 PreCompact (`:102-109`) + 1 SubagentStop (`:112-120`) |
| CLAUDE.md table rows | **5** | `CLAUDE.md:690-696` -- collapses `Stop` and `PreCompact` into one row since both delegate to the same command |

For planning a new registration (GateGuard or hookify), **10 is the operative number**: it is how
many independent matcher blocks already exist and could collide with, or need to coexist beside, a
new one.

### 1.2 Full inventory, event / matcher / delegate / exit contract

| Event | Matcher | Delegates to | Exit-code contract |
|---|---|---|---|
| `SessionStart` | (none) | `edm-state session-start` (`hooks.json:8`) | Best-effort: `command -v ... && ... \|\| true` -- never fails the session |
| `UserPromptExpansion` | `edm:srd` \| `edm:audit-srd` \| `edm:tickets` \| `edm:audit-tickets` \| `edm:implement` (5 separate blocks) | `edm-state gate-check <PREFIX> <cmd>` (command hook) + an advisory `prompt`-type hook per block (`hooks.json:19-24`, repeated per matcher) | Exit 3 from `gate-check` -> command hook `exit 2` (blocks expansion); any other non-zero (missing binary, unresolvable prefix, missing jq) -> `exit 0` (CA-298, confirmed at `CLAUDE.md:693` and in the inline shell at e.g. `hooks.json:19`) |
| `PreToolUse` | `git commit` | `edm-lint-staged-artifacts` (`hooks.json:86`) | `edm-lint-staged-artifacts` exit 2 = block; exit 1 = setup error, non-blocking; exit 0 = clean (`bin/edm-lint-staged-artifacts:7-10`, confirmed at `bin/edm-lint-staged-artifacts:150-158`) |
| `Stop` | (none) | `edm-state checkpoint-if-active` (`hooks.json:96`) | `... && ... \|\| true` -- never blocks |
| `PreCompact` | (none) | `edm-state checkpoint-if-active` (`hooks.json:106`) | same as Stop -- never blocks |
| `SubagentStop` | `edm-implementer` | An inline `prompt`-type hook that spawns `edm-qc-auditor` (`hooks.json:117`) | Not a command hook; no exit-code contract, it is agent-spawning prose |

**PreToolUse today has exactly one matcher block, scoped to `git commit`.** There is no
`PreToolUse` registration matching `Edit`, `Write`, or `MultiEdit` anywhere in this plugin. This is
the gap 4.1 (GateGuard) would fill, and it is a genuine gap, not a documentation omission --
confirmed by reading the entire `hooks.json` file top to bottom (124 lines, no other `PreToolUse`
block exists).

### 1.3 The JSON deny shape does not exist anywhere in this repository

I grepped the whole `marketplace` repository for both `permissionDecision` and
`hookSpecificOutput`. **Zero matches outside `plugins/edm/docs/ecc-integration-analysis.md`
itself.** Every EDM hook that blocks anything today does so via a **bash exit code**
(`edm-lint-staged-artifacts` exit 2; `gate-check`'s exit-3-mapped-to-exit-2 convention). EDM has
**no precedent anywhere** for the
`{hookSpecificOutput: {permissionDecision: 'deny', permissionDecisionReason: ...}}` JSON-on-stdout
shape GateGuard's mechanism requires. This is not a small implementation detail -- it is a second,
previously-unused hook response protocol that EDM's own tooling (`edm-check-vocabulary`,
`edm-lint-artifacts`, the smoke tests) has never had to reason about. Building GateGuard as a
bash-exit-code hook instead (deny = a specific exit code + a message on stderr that Claude Code
surfaces) would need to be verified against Claude Code's actual `PreToolUse` contract for
`Edit`/`Write`/`MultiEdit` specifically -- **I could not verify from this repository's source
whether an exit-code-only `PreToolUse` hook can actually deny an `Edit`/`Write`/`MultiEdit` the way
it denies a `git commit`'s underlying `Bash` call**, since the one blocking precedent EDM has
(`git commit`) is itself a `Bash`-tool invocation, not a native `Edit`/`Write`/`MultiEdit`. Confirm
this mechanically before committing to bash-exit-code as GateGuard's contract; if it does not work
for those three tools specifically, GateGuard is a hard requirement to adopt the JSON shape, not an
option.

### 1.4 Resolving "is Phase 6 active" from inside a hook -- no existing cheap path

The analysis (4.1) correctly identifies the problem: `edm-state get <PREFIX> current_phase` exists
(dispatch table entry `get) cmd_get "$@" ;;` at `bin/edm-state:6240`, `cmd_get` at
`bin/edm-state:2001-2004`) but requires a `PREFIX` argument a `PreToolUse` hook does not receive.

What EDM already has that comes closest:

- **`cmd_active_initiatives`** (`bin/edm-state:3900-3916`) -- globs `list_state_files`
  (`bin/edm-state:128-147`, itself a cheap shell glob with no subprocess), then runs one `jq`
  invocation **per discovered state file** to read `.current_phase`, filtering to phases 1-6.
  Cost scales with the number of *any* active initiatives in the whole `SRD/` tree, not just the
  one relevant to the current session.
- **`cmd_session_start`** (`bin/edm-state:4347` onward) does the same sweep, called once per
  `SessionStart` -- an event that fires once per conversation, not once per tool call.
- **`cmd_checkpoint`** (called by `checkpoint-if-active`, `bin/edm-state:2735` onward) does a
  **heavier** version of the same sweep -- for every active state file it takes a write lock
  (`rmw_state`), re-reads the file, and computes a SHA-256 hash of every tracked artifact
  (`artifact_hash`, drift detection loop at `bin/edm-state:2781-2799`) to detect out-of-band edits.
  This already runs on every `Stop` and every `PreCompact`, i.e. at most a few times per
  conversation turn -- **not** per tool call.

**Nothing in `bin/edm-state` writes a lightweight "here is the currently active
initiative/phase" pointer file anywhere.** I grepped for `CLAUDE_PLUGIN_DATA` across
`plugins/edm/bin/edm-state` and the whole `plugins/edm/` tree: it appears in `CLAUDE.md` (as prose
reserving it for "plugin-internal caches only") and in the analysis doc, but **zero times** in any
executable script. So the "which initiative is active" problem is solved today only at
`SessionStart`/`Stop`/`PreCompact` cadence (a handful of times per conversation), never at
per-tool-call cadence, and no cache exists that a `PreToolUse` hook could read cheaply instead of
re-running the sweep.

**What GateGuard would need that does not exist yet:** a marker written once when Phase 6 starts
(e.g. by `/edm:implement`'s Phase 6 preflight, or by `cmd_phase_start` itself when
`current_phase` transitions to 6) at a path the hook can `test -f` / `cat` without invoking
`edm-state`'s full ~6,300-line dispatch at all -- for example a one-line file under
`${CLAUDE_PLUGIN_DATA}/active-phase6-prefix` or inside the initiative directory itself, cleared on
Gate approval past Phase 6 / on `phase-complete`. **This does not exist in the current tree.**
Building it is in scope for 4.1, not a reuse of something already built.

### 1.5 Per-tool-call latency estimate

Every `edm-state` invocation pays: (a) bash parsing/loading a ~6,300-line script (`wc -l`
equivalent confirmed structurally -- the dispatch `case` block starts at `bin/edm-state:6239` and
the file runs through `bin/edm-state:6288`; 39 subcommand arms counted directly against
`CLAUDE.md:799`'s claim of 39, and they match exactly), (b) at least one `jq` subprocess per state
read. Bash script *parsing* cost for a file this size is small (single-digit milliseconds on
modern hardware) but not zero, and it is paid **fresh on every invocation** since each hook
invocation is a new process with no warm interpreter to reuse -- the same "N Node startups" problem
1.6 of the analysis describes for ECC's dispatcher, translated to "N bash+jq startups."

Given no cache exists (1.4), the cheapest correct implementation of a Phase-6-scoped
`PreToolUse` gate today would be one of:

1. Re-run something like `cmd_active_initiatives`'s sweep on every `Edit`/`Write`/`MultiEdit` --
   cost scales with total active-initiative count across the whole `SRD/` tree, paid on **every**
   edit in the session, not once. For a repo with a handful of concurrent initiatives this is a
   few `jq` calls per edit; for the `--all`-scale fixture CLAUDE.md's own latency table already
   uses for a different budget (50 initiatives, `CLAUDE.md:816-824`), this would be 50 `jq`
   invocations per edit -- clearly the wrong shape for a per-edit gate.
2. Build the marker file described in 1.4 and have the hook do a single `test -f` /
   `cat` with **no** `edm-state` invocation at all on the common (allow) path. This is the only
   design that keeps per-edit cost roughly constant regardless of `SRD/` size, and it does not
   exist yet.

**Verdict on the dispatcher-consolidation question (1.6 of the analysis):** at EDM's current hook
count (10 matcher blocks across 6 events, one of which -- `PreToolUse` -- has exactly one entry
today), a Node-style multi-hook-in-one-process dispatcher is not yet justified purely by hook
*count*. It becomes relevant the moment GateGuard is added and paired with a hookify dispatcher
(5.3) on the *same* event (`PreToolUse` would then have two-plus independent matcher blocks, one
of which -- GateGuard -- runs on every single edit). The latency risk here is not "too many
hook registrations" (ECC's problem, 25 across 8 events) but "one registration invoked at a
much higher frequency than anything EDM's hooks do today" -- a different failure mode than the one
1.6 names, and EDM should not import the ECC fix (a shared dispatcher process) as the answer to
this different problem. The answer for EDM is the cheap-marker design in 1.4, not consolidation.

---

## 2. hookify (5.3) -- where a rules dispatcher would register and what it collides with

`PreToolUse` today has **one** matcher block (`git commit`, `hooks.json:81-89`). A hookify
dispatcher matching `bash`/`file`/`stop`/`prompt`/`all` events (per the analysis's rule-file
schema) would need a **broad** matcher (effectively "everything," since rules are decided by
rule-file content, not by the hook matcher) on both `PreToolUse` and `Stop`. That means:

- On `PreToolUse`, it would add a **second, independent matcher block** covering `Edit`/`Write`/
  `MultiEdit`/`Bash`/anything the loaded rules care about -- overlapping in principle with
  whatever matcher GateGuard (4.1) also registers on the same event, if 4.1 is ever adopted. Two
  independently-authored `PreToolUse` blocks that can both fire on the same tool call is a real
  collision surface: EDM has no existing convention for what happens when two `PreToolUse` command
  hooks on the same tool call disagree (one allows, one denies), because today there has only ever
  been **one** `PreToolUse` block in the entire file.
- On `Stop`, it would add a **second** `Stop` registration alongside the existing single one
  (`hooks.json:91-99`, `edm-state checkpoint-if-active`). `hooks.json`'s own shape proves multiple
  matcher blocks *can* coexist on one event -- `UserPromptExpansion` already carries five
  independent matcher blocks (`hooks.json:14-78`) that Claude Code evidently executes without
  requiring them to be merged into one. That is in-repository, structural evidence that **adding**
  is mechanically supported. It is **not** evidence for how the host sequences or combines their
  exit codes/decisions when more than one block matches the *same* tool call on the *same*
  event -- `UserPromptExpansion`'s five blocks are matcher-disjoint (each fires on a different slash
  command), so EDM has never actually exercised the "two blocking hooks both match this one call"
  case. **I could not verify Claude Code's exact multi-hook-per-event combination semantics from
  this repository's source** -- nothing in `hooks.json`, `CLAUDE.md`, or `README.md` documents it,
  and I have no external documentation access in this exploration. This is the single most
  important thing to confirm mechanically (a small spike, same pattern as the D21/D22/D24 spikes
  already recorded in `decisions.md` for other Claude Code behaviors this plugin depends on) before
  building either GateGuard or hookify, and doubly so if both are ever adopted together on
  `PreToolUse`.
- The `SubagentStop` block (`hooks.json:111-121`) and the five `UserPromptExpansion` blocks are
  matcher-scoped narrowly enough (`edm-implementer`; specific slash-command names) that a hookify
  dispatcher's own rule events (`bash`/`file`/`stop`/`prompt`/`all`) would not naturally collide
  with them unless a rule author deliberately wrote a rule targeting those same triggers.

**Recommendation for the planning doc:** hookify's dispatcher is not "add one more hook," it is
"introduce EDM's first-ever *multiple independent blocking hooks on one event* situation" on both
`PreToolUse` and `Stop`. That reclassifies it from medium-effort/low-risk (the analysis's rating,
`ecc-integration-analysis.md:729`) to medium-effort/**risk contingent on a currently-unverified
host behavior**.

---

## 3. Stop-hook completion gate (5.4) -- anomaly inventory and current exit-code behavior

### 3.1 `cmd_validate` (`bin/edm-state:4036-4059`) and `state_anomalies` (`bin/edm-state:1709-1927`)

`cmd_validate` prints every anomaly `state_anomalies` emits, in a four-field format
(`class name field message`, per `bin/edm-state:4045`), and returns **exit 3** if and only if at
least one line's first field is literally `blocking` (`bin/edm-state:4048-4054`). Every other
condition returns 0.

Full anomaly inventory, verified against source:

| Anomaly | Class | Line(s) | One of the analysis's four named candidates? |
|---|---|---|---|
| `TIME_ORDER` -- `completed_at` earlier than `started_at` for a phase | **blocking** | `bin/edm-state:1714-1729` | No |
| `SIZE_UNKNOWN` -- `estimated_size` still `"Unknown"` at phase >=2 | info | `bin/edm-state:1730-1740` | No |
| `ZERO_TOKENS` -- `model_used` set but both token counts are 0 | **blocking** | `bin/edm-state:1741-1752` | No |
| `TORN_TOKEN_LINES` -- unparseable session-JSONL lines (phase, x2 for audit rounds) | info | `bin/edm-state:1753-1783` | No |
| `OPEN_AUDIT_ROUND` -- an audit round started, never completed | info | `bin/edm-state:1784-1801` | **Yes** -- confirmed exactly as the analysis names it (`ecc-integration-analysis.md:759-760`), and confirmed **informational**, never flips `validate`'s exit code (comment at `bin/edm-state:1788-1789` states this explicitly) |
| `PERM_RULES_MISSING` -- required `ask` permission rules absent | info | `bin/edm-state:1802-1814` | No |
| `CONVERGED_NO_APPROVAL` -- `code_audit_converged=true` with no approval record | **blocking** | `bin/edm-state:1815-1826` | No |
| `OPEN_PARTIALS` -- a `partial_verdict_map` entry is open or FAIL-closed | **blocking** | `bin/edm-state:1827-1847` | **Yes** -- confirmed exactly, and confirmed **blocking** at `validate` time already (contrary to a naive reading of the analysis, which frames all four candidates as "fire too late," this one already fires at `validate`, not only at `archive`) |
| `LEGACY_LIFECYCLE_MODE` -- stale `lifecycle_mode: partial` value | info | `bin/edm-state:1848-1857` | No |
| `SCHEMA_VERSION_MISSING` | info | `bin/edm-state:1858-1869` | No |
| `EMPTY_SKIP_RATIONALE` / `ACTIVE_EXEMPTION` (skipped_phases) | info | `bin/edm-state:1870-1888` | No |
| `ACTIVE_EXEMPTION` (archive_exemptions) | info | `bin/edm-state:1889-1897` | No |
| `ACTIVE_EXEMPTION` (degraded_checks) | info | `bin/edm-state:1898-1906` | No |
| `SPEC_SWEEP_PENDING` -- a `fixed` ledger finding with `spec_swept: "no"` | info | `bin/edm-state:1907-1926` | **Yes** -- confirmed exactly, and confirmed **informational** at `validate` (comment at `bin/edm-state:1911-1913` states the blocking enforcement lives at `audit-converged`/`approve-gate` instead, not at `validate`) |

**The fourth named candidate -- "a phase started with no `completed_at`" -- does not exist as its
own anomaly.** `TIME_ORDER` (the only anomaly touching `started_at`/`completed_at` together) only
fires when **both** timestamps are present and `completed_at < started_at`
(`bin/edm-state:1721-1728`); a phase with `started_at` set and `completed_at` simply **absent**
(the normal in-progress state, or the EDMV2-era failure mode the `OPEN_AUDIT_ROUND` comment
references for a whole phase rather than one audit round) produces **no anomaly line at all**
today. This is a real gap, not a classification question -- if 5.4 is adopted, this candidate
needs a **new** anomaly definition in `state_anomalies`, not a reclassification of an existing one.
Treat "verify each exists" as **3 of 4 confirmed, 1 of 4 does not exist yet**.

### 3.2 Classifying each verified candidate for Stop-time enforcement

Per the task's (a)/(b) split -- unambiguous enough to block at `Stop`, vs. warn-only:

| Candidate | Current class | Recommended Stop-time classification | Rationale |
|---|---|---|---|
| `OPEN_AUDIT_ROUND` | info | **(b) warn-only** | A round genuinely in progress mid-audit is the normal state for most of the audit's duration (the comment at `bin/edm-state:1786-1789` says exactly this) -- blocking on it at every `Stop` during a multi-turn audit session would refuse constantly for a condition that resolves itself minutes later. |
| `OPEN_PARTIALS` | **already blocking at `validate`** | (a) already unambiguous -- surfacing at `Stop` too is a **timing improvement only** (the analysis's own framing, `ecc-integration-analysis.md:544`), not a new blocking decision | This is the strongest candidate to actually block at `Stop`, since it already blocks at `validate` and at `archive`; extending `Stop` to call `validate` and honor its exit code costs nothing new in classification risk. |
| `SPEC_SWEEP_PENDING` | info at `validate`, blocking at `audit-converged`/`approve-gate` | **(b) warn-only at `Stop`**, consistent with its current `validate` classification | The blocking enforcement already exists at the two gates the analysis names as sufficient (`bin/edm-state:1911-1913`); duplicating that block at `Stop` would fire on every single `Stop` for the entire remainder of a round in which any finding is mid-sweep, which is a much higher-frequency block than the gate it currently sits at. |
| Phase started with no `completed_at` | **does not exist yet** | Needs to be designed, not classified | Requires a new anomaly definition first. A phase that has been "started" for an entire multi-hour Phase-6 wave is completely normal, so a naive presence check would need a time threshold or an explicit "wave in progress" carve-out to avoid blocking on ordinary long-running work -- this is new design, not a small addition. |

### 3.3 What `archive` blocks on today (the analysis's stated baseline)

Confirmed directly in `cmd_archive` (`bin/edm-state:3096-3326`):

1. Missing required gate approvals for the mode (`die` at `bin/edm-state:3171`).
2. `current_phase` not at the mode's terminal phase (`die` at `bin/edm-state:3179`).
3. Terminal phase has no `completed_at` (`die` at `bin/edm-state:3185`) -- note this check
   **already exists, but only for the terminal phase specifically**, not for any phase generally
   the way a Stop-hook version of the fourth candidate would need to.
4. `code_audit_converged` false (two `die` sites: legacy branch `bin/edm-state:3153`, normal branch
   `bin/edm-state:3225`).
5. Any `partial_verdict_map` entry open or FAIL-closed (`die` at `bin/edm-state:3260`) -- this is
   `OPEN_PARTIALS` re-checked directly against state rather than via `validate`.
6. A failing `audit-converged` re-query, unless P2-debt-accepted and stale-guarded
   (`die` at `bin/edm-state:3306`).

No override flag exists for any of these (`bin/edm-state:3107`, `:3119-3120`). This confirms the
analysis's premise structurally: everything in 3.2's table (except the not-yet-existing fourth
candidate) is enforced no later than `archive`, and `OPEN_PARTIALS` specifically is enforced
identically at both `validate` and `archive` today -- so 5.4's actual proposal is "run the same
check that already exists, earlier," which is a low-risk change confined to wiring, not new
policy.

---

## Component inventory

| Component | Path | Status | Notes |
|---|---|---|---|
| `hooks.json` PreToolUse block | `plugins/edm/hooks/hooks.json:80-90` | Modified (4.1, 5.3) | Currently one matcher (`git commit`); GateGuard and/or hookify would add matcher block(s) here -- first time this event has more than one |
| `hooks.json` Stop block | `plugins/edm/hooks/hooks.json:91-100` | Modified (5.3, 5.4) | Currently one hook (`checkpoint-if-active`); 5.4 extends or adds a sibling entry running `validate` |
| GateGuard fact-forcing hook | new `bin/edm-gateguard` (or vendored JS) | New (4.1) | No existing file; must invent both the JSON-deny-shape mechanism (unprecedented in this repo, Sec 1.3) and the Phase-6-scope marker (unprecedented, Sec 1.4) |
| Phase-6-active marker/cache | new, path TBD (e.g. `${CLAUDE_PLUGIN_DATA}/active-phase6-prefix`) | New (4.1) | Blocking prerequisite for 4.1's latency target; does not exist; no producer (`phase-start`/`phase-complete`) writes anything like it today |
| `cmd_active_initiatives` | `bin/edm-state:3900-3916` | Exists | Nearest existing "which initiatives are active" primitive; wrong cadence (fine for `SessionStart`, wrong for per-edit) |
| `cmd_checkpoint` | `bin/edm-state:2735` onward | Exists | Nearest existing per-Stop sweep; already does write-locking + hashing per active initiative -- a ceiling example of "too expensive to run per-edit" |
| `cmd_validate` / `state_anomalies` | `bin/edm-state:4036-4059`, `:1709-1927` | Exists | Full anomaly inventory in Sec 3.1; reusable as-is by a `Stop` extension (5.4) with no anomaly-logic changes for `OPEN_AUDIT_ROUND`/`SPEC_SWEEP_PENDING`/`OPEN_PARTIALS` |
| Phase-started-no-completed_at anomaly | none | New (5.4) | Does not exist in `state_anomalies`; needs design (threshold/carve-out for long-running phases) before it can classify as blocking or warn |
| hookify rule loader/dispatcher | new `bin/edm-hookify` + rule files under `SRD/` or `.claude/` | New (5.3) | No existing rules-as-data mechanism in this plugin; multi-hook-per-event combination semantics on `PreToolUse`/`Stop` are unverified from source (Sec 2) |
| `edm-lint-staged-artifacts` | `plugins/edm/bin/edm-lint-staged-artifacts` | Exists | The one precedent for a blocking `PreToolUse` hook in this plugin; exit-code-only, not JSON-deny-shape |
| Monitors (`edm-impl-progress`) | `plugins/edm/monitors/monitors.json` | Exists, out of scope | Read-only `git log` poll, unrelated to any of the three scope items; confirmed unchanged by this exploration |

---

## Constraints

- **No JSON-deny-shape precedent anywhere in the repo** (Sec 1.3). Any GateGuard implementation
  either introduces this response format for the first time, or must prove the exit-code contract
  actually works for native `Edit`/`Write`/`MultiEdit` tool calls (not just `Bash`-wrapped ones) --
  unverified from source either way.
- **No per-tool-call-cheap "which initiative/phase is active" cache exists** (Sec 1.4). This is a
  hard prerequisite for 4.1 at acceptable latency, not an optional optimization.
- **Multi-hook-per-event combination semantics on `PreToolUse`/`Stop` are unverified** (Sec 2).
  EDM's own `hooks.json` has never had two independently-authored blocking hooks compete on the
  same tool call; this is new territory for both 4.1 and 5.3, and doubly so if adopted together.
- **`edm-check-vocabulary` and `edm-lint-artifacts` both scan `hooks/hooks.json` and
  `monitors/monitors.json`** (`CLAUDE.md:806`) -- any new hook/monitor JSON content must stay
  within the vocabulary/lint rules those scripts enforce (ASCII-only per
  `CLAUDE.md:731-732`, no abolished-vocabulary terms).
- **One of the analysis's four named `validate` anomaly candidates does not exist** (Sec 3.1) --
  the "phase started with no `completed_at`" check needs new design work, not just a Stop-hook
  wiring change, before 5.4 can honor its own stated scope.

## Dependency map

- 4.1 (GateGuard) depends on: a new Phase-6-active marker mechanism (no current owner; likely
  `cmd_phase_start`/`cmd_phase_complete` in `bin/edm-state`) being built **first**, or GateGuard's
  latency is unacceptable per Sec 1.5.
- 4.1 also depends on resolving the JSON-deny-shape-vs-exit-code question (Sec 1.3) before any
  implementation work, since the two mechanisms are not interchangeable refactors of each other.
- 5.3 (hookify) and 5.4 (Stop extension) both write to the same `Stop` event surface as each other
  and as the existing `checkpoint-if-active` registration -- sequencing/ownership between the three
  needs to be decided once (who owns the single `Stop` hook body, or how many separate `Stop`
  blocks coexist) rather than each being designed against a `Stop` event assumed to be otherwise
  empty.
- 5.3 and 4.1 both want `PreToolUse` -- if both are adopted, the multi-hook-combination spike
  (Sec 2) blocks both, not just one.
- 5.4's `OPEN_PARTIALS`-at-Stop path has no new dependency (the check and its blocking semantics
  already exist at `validate`); the "phase with no `completed_at`" path depends on new anomaly
  design work with no existing owner.

## Complexity estimate (this area only)

- **Files affected**: `hooks/hooks.json` (1), `bin/edm-state` (anomaly additions + new marker
  read/write commands, if 4.1's marker lands there), a new GateGuard script (1, new), a new
  hookify loader/dispatcher script (1, new), possibly `CLAUDE.md`'s "Hooks behavior" table (1).
  Roughly 4-6 files depending on how many of the three items are taken together.
- **New modules needed**: 2 (GateGuard hook script; hookify rule loader/dispatcher), plus one new
  small primitive (the Phase-6-active marker read/write pair) that either item could reuse if 4.1
  lands first.
- **Integration points**: 3 (`PreToolUse`, `Stop`, and `bin/edm-state`'s dispatch table / anomaly
  function), each carrying the unverified-semantics risk noted above.
- **Estimated ticket size**: **Medium (30-50)** for 4.1 alone once the marker and deny-shape
  questions are resolved by spike; **Small (10-20)** for 5.4 given `OPEN_PARTIALS`/
  `OPEN_AUDIT_ROUND`/`SPEC_SWEEP_PENDING` reuse existing, already-classified logic, but only if the
  fourth candidate (no-`completed_at`) is either descoped or given its own small design pass; 5.3
  is **Medium (30-50)** on its own and should not be scheduled concurrently with 4.1 without the
  Sec 2 spike resolved first, since both compete for the same `PreToolUse` surface.

## Riskiest assumptions

1. **That an exit-code-only `PreToolUse` hook can deny a native `Edit`/`Write`/`MultiEdit` call the
   same way the existing hook denies a `git commit`'s `Bash` invocation.** EDM's only blocking
   precedent is on `Bash`; this has never been exercised on the three tools GateGuard targets.
2. **That Claude Code executes multiple matching hooks on one event/tool-call independently
   (rather than, say, only the first-registered, or requiring them to be merged into one
   process).** The only in-repo evidence (`UserPromptExpansion`'s five matcher-disjoint blocks) does
   not actually test two hooks matching the *same* call.
3. **That a file-based marker read on every `Edit`/`Write`/`MultiEdit` is actually cheap enough** --
   plausible and standard practice, but not measured against this plugin's actual per-edit
   frequency in a real Phase-6 session; no timing fixture exists for this today the way
   `bin/tests/timing.sh` measures `edm-lint-artifacts`.
4. **That GateGuard's self-reported +2.25/10 result generalizes to EDM's implementer/QC loop at
   all.** Per the task's caution and the analysis's own Sec 8.3: n=2, self-reported, unblinded, no
   published rubric. The mechanism (forced investigation beats self-assessment) is structurally
   sound and matches EDM's own audit-lens premise, but the *effect size* claim should not appear in
   planning.md as anything more than "directional."
