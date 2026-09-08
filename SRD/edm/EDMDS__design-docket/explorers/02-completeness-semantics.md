# Explorer 02 -- Completeness-gate and audit-round semantics (Epic 2: CA-074, CA-075, CA-089, CA-090, CA-091)

Scope: all five findings live in `plugins/edm/bin/edm-state`. Everything below is established by
reading the current code on this branch (`edm/edmv4-ecc-integration`), not by trusting
`REMEDIATION.md`'s line numbers (which are stale -- they cite the 2026-09-04 snapshot) or
`CLAUDE.md`'s prose (checked, but treated as a claim to verify, not a source of fact). Current
`file:line` references below are re-derived against the live file.

**Naming collision flagged up front**: `bin/edm-state:154` carries a comment `# G21/CA-074: ...`
about `die()`'s two-argument form. That is a **different, unrelated finding from a different
audit ledger** that happens to reuse the ID `CA-074`. `CA-NNN` IDs are scoped to one initiative's
`findings-ledger.jsonl`, not globally unique across the repository's history -- do not conflate the
two. All five IDs in this report are EDMV4 pass-1's, as listed in
`SRD/.archived/edm/EDMV4__ecc-integration/code-audit/pass-1_2026-09-04/REMEDIATION.md`.

---

## CA-090 -- what the CA-471 completeness gate actually checks

**Established.** The gate lives in `_cmd_audit_round_complete_body()`, check (1),
`bin/edm-state:5153-5165`. The operative test, `bin/edm-state:5158`:

```bash
if [[ ! -s "$_lens_file" ]] || ! jq empty "$_lens_file" >/dev/null 2>&1; then
```

Two conditions, both must pass:
1. `-s` -- the file exists and is non-empty (any non-zero byte count).
2. `jq empty "$_lens_file"` exits 0 -- the file's bytes parse as a well-formed sequence of JSON
   values under jq's default (whitespace-concatenated) input mode.

That is the **entire** content check. Nothing here inspects field names, field types, or field
values. `jq empty` succeeds on:
- `{}` (a single empty object)
- `[]` (a single empty array)
- `1` or `"x"` (a bare scalar)
- any number of well-formed JSON values on one or many lines

A placeholder `lens-L{N}.jsonl` containing the single line `{}` satisfies check (1) exactly as
well as a real lens report containing fourteen correctly-shaped finding lines. Confirmed: no other
site in `_cmd_audit_round_complete_body` (checks (2) or (3), `:5167-5196`) reads the *content* of
any lens file either -- (2) only tests file **existence** for `lenses_na` members (`:5171-5175`,
`[[ -e "$_lens_file" ]]`), and (3) is a pure set-membership comparison over the round record in
state, touching no file at all.

**Downstream check, also established: none exists.** `agents/edm-audit-synthesizer.md:204`
instructs the synthesizer to `LS` the pass directory and `Read` each `lens-L{N}.jsonl` -- this is an
LLM agent's read, not a machine-enforced schema check. There is no second, mechanical validator
anywhere between the CA-471 gate and the synthesizer.

**What a real lens line must contain, per the house contract** --
`agents/edm-audit-logic.md:85-105` (verified against the actual lens-agent source, not against
`CLAUDE.md`'s summary of it):

```
{"schema":1,"id":null,"lens":"L1","round":N,"round_type":"full|partial","sev":"P0|P1|P2|NOTED","confidence":"high|medium|low","file":"path","line":42,"title":"...","status":"open"}
```
- `sev` in `{P0, P1, P2, NOTED}`
- `confidence` in `{high, medium, low}` -- mandatory on every line
- `status` in `{open, fixed, noted}`
- one object per line, no trailing comma

**Minimum honest check (a fact about the gap, not a recommendation):** the current gate could
require, per lens file, at least one line that parses as a JSON *object* (not merely a JSON value)
carrying `"lens"` equal to the expected `L{N}` and `"sev"` one of the four legal tokens. That would
reject `{}`/`[]`/bare-scalar placeholders while still passing a genuine zero-finding lens report
(which the schema comment at `agents/edm-audit-logic.md:88-89` says must still emit at least one
`NOTED` line per lens agent's own contract -- "every lens agent" is not stated to have a legitimate
zero-line output). Whether that is the *right* minimum, or whether it should also check `round`/
`round_type` agreement with the round record, is the open decision below.

**Open decision:** what must a `lens-L{N}.jsonl` file contain to count as "delivered"?
- **Option A (status quo):** non-empty + parseable. Cost: proves nothing about content; a lens
  agent that silently produced no real output (crash, truncation, wrong-tool-call) still converges
  the round if it writes any parseable placeholder.
- **Option B (object + lens-ID + legal sev, per line, at least one line):** closes the placeholder
  gap this finding names. Cost: a small, mechanical jq addition to the existing check; needs a
  decision on whether a single malformed *line* among otherwise-good lines fails the whole file or
  is tolerated (the current file-level check has no concept of "some lines good, some bad").
- **Option C (full schema validation, all fields, every line):** most complete; highest cost to
  build and to keep in sync with the schema in `agents/edm-audit-logic.md`'s "verbatim in every
  lens prompt" comment (`:91`) if that schema is ever revised, and slowest to run across 14 files.

---

## CA-091 -- the three-way backstop's gating condition, and the no-manifest escape

**Established.** The entire CA-471 completeness apparatus (all three checks, `:5153-5196`) sits
inside one guard, `bin/edm-state:5144`:

```bash
if [[ -n "$_pass_dir" && -f "$_manifest" ]]; then
```

`_pass_dir` is populated only if a directory matching `${_init_dir}/code-audit/pass-${round_num}_*`
exists on disk (`:5117-5142`); `_manifest` is `${_pass_dir}/lenses-run.txt`. If **either** is
missing -- no `pass-N_*` directory at all, or a directory with no `lenses-run.txt` -- the `if` body
never runs. There is no `else` arm. `ca471_downgrade` stays `""` (set at `:5115` and never
reassigned), and the write at `:5200-5222` only overrides `round_type` when
`\$rt471 != ""` (`:5214`). So on the no-manifest path, whatever `round_type` was recorded at
`audit-round-start` time is written back unchanged.

**Confirmed by control flow, not merely by the finding's own text:** a round for which the lens
agents produced **nothing on disk at all** -- no pass directory, meaning no lens even attempted a
`Write` -- still completes with `round_type` exactly as `audit-round-start` set it. Since
`audit-round-start`'s default (no `--lenses` passed) materializes `lenses = ALL_LENS_IDS` and the
union-rule computes `full` whenever `--na-lenses` is empty or a proper subset covered by that
materialization (`:5038-5042`), the ordinary un-instrumented call sequence records `round_type:
"full"` for a round that delivered zero files.

**The finding's own text is independently corroborated in this repository's own history.**
`SRD/.archived/edm/EDMV4__ecc-integration/decisions.md` D40 records this exact gap as a known,
accepted residual at the time `EDMV4-T23` shipped: *"A code round that produces NO manifest --
arguably the strongest non-delivery signal there is -- escapes the backstop entirely, exactly as
it did before this ticket."* D40 reserved a named follow-on prefix, `CAMGAP` (code-audit manifest
gap), verified free via `edm-validate-prefix` on 2026-09-03 -- and it was never used. CA-091 is
that follow-on, arriving via this docket instead.

**Open decision:** what should a missing manifest mean?
- **Option A (treat as full-round failure -- add an `else` that hard-refuses or forces
  `round_type=partial`):** matches the finding's own suggested fix ("a round that produced no pass
  directory is an error, not a full round"). Cost: must first decide what "no manifest" means for
  a `srd`/`tickets` audit_type, which never has a manifest concept at all (D40 names this exact
  ambiguity as the reason the gap was left open rather than closed inline) -- an undiscriminating
  `else` would misfire on every legitimate non-`code` round.
- **Option B (scope the `else` to `audit_type == "code"` only):** closes the code-round gap
  without touching `srd`/`tickets`. Cost: still has to decide the exact refusal shape (hard `die`
  inside `audit-round-complete`, vs. a silent `round_type=partial` downgrade like the three
  existing checks) and whether a `code` round that legitimately used `--lenses` with a scope that
  never launches a real Task-tool agent (e.g., a dry test call) is distinguishable from a genuine
  non-delivery.
- **Option C (leave as documented, accepted debt):** status quo; D40's reasoning that this is new
  design, not a natural extension, stands. Cost: the gap this finding names remains open indefinitely
  and a round that silently produced nothing can still converge.

---

## CA-089 -- irreversibility and the real cost of "run a new round"

**Where irreversibility is enforced -- confirmed, two independent points:**

1. **Double-completion refusal**, `bin/edm-state:5072-5073`:
   ```
   [[ -z "$already_completed_at" ]] \
     || { echo "...is already completed (at ${already_completed_at}); a round may be completed only once" >&2; return 1; }
   ```
   Once a round has a `completed_at` timestamp (set only by a first successful
   `audit-round-complete`), a second `audit-round-complete` call for the same round number is
   refused outright. This is what makes a `round_type=partial` downgrade permanent for that round
   number: there is no second attempt at the completeness check for it, ever.

2. **Each of the three CA-471 downgrade messages says so explicitly** (`:5163`, `:5177`, `:5193`),
   e.g.: *"recording round_type=partial (non-convergent); persist the missing lens-L{N}.jsonl
   halves and note the miss in tooling-notes.md, then run a NEW round to converge -- this round
   cannot be re-completed, so persisting the halves does not restore round_type=full."*

**No re-poll exists.** The check runs exactly once, synchronously, at the moment
`audit-round-complete` is invoked (`:5116-5198`, no loop, no sleep, no retry). **No repair
subcommand exists either** -- grepped `bin/edm-state` for `repair|re-poll|recomplete` and found
zero hits touching this path (the three hits that do exist are unrelated: `migrate-schema`'s
"repair the state file by hand" message at `:3330`, `archive`'s generic "repair the findings
ledger data" advice at `:3633`, and the three CA-471 messages themselves).

**What "run a NEW round" costs, from this plugin's own recorded data -- not an estimate.**
`SRD/.archived/edm/EDMV4__ecc-integration/.edm-state.json:189,198` records EDMV4's own round 1:
`duration_seconds: 11674` (3h 14m 34s) and `estimated_cost_usd: 105.2798`. That is the price of
one full 13-lens round (L13 legitimately N/A) on this plugin's own codebase. A round downgraded to
`partial` by a transient miss on even one lens file has no cheaper recovery than re-running the
whole round: `audit-converged`'s refusal is keyed on the **latest** round's `round_type`
(`bin/edm-state:5353`, `elif [[ "$latest_round_type" == "partial" ]]`), so a later "repair round"
that reruns only the missing lens would itself record `round_type=partial` (a 1-of-14 union does
not cover `ALL_LENS_IDS`) and would not restore convergence either -- only a subsequent round whose
own `lenses`/`lenses_na` union covers all 14 lens IDs converges.

**Nuance on how often the downgrade fires from a genuine race vs. a genuine gap:**
`skills/code-audit/SKILL.md:102-116` (step 8a) already has the orchestrator Glob-count every
`lens-L*.jsonl` and refuse to proceed to synthesis until the count matches `|LENS_SET|`, persisting
any lens's returned text as both `.md` and `.jsonl` by hand if a Write never landed. This
substantially narrows the race window between "a lens agent finished" and "its JSONL is on disk"
before `audit-round-complete` is ever called -- so the downgrade this finding is about fires
primarily on a **genuine** gap (a lens that truly produced no valid output, or an operator/skill
step 8a check that was skipped or itself buggy), not routinely on ordinary async landing lag. This
matters for costing the decision: the $105/3h15m figure is the price of a real miss, not the
routine price of async timing.

**Open decision:** should a downgraded round be repairable, or is one-shot-per-round correct?
- **Option A (status quo -- irreversible):** simplest to reason about; a round's `round_type` is
  fixed the moment it is written. Cost: the full $105/3h15m re-run price for any single-lens miss,
  however caused, with no cheaper path.
  On EDMV4's own round-1 cost, this is roughly $30-$40/hour of the initiative's realized code-audit
  spend.
- **Option B (bounded re-poll before downgrading, e.g. a few retries with backoff inside
  `audit-round-complete` itself):** closes the narrow async-landing-lag case for free (no new
  subcommand), but does **not** help a genuine gap (a lens that never wrote a valid file at all,
  which retrying a few seconds later will not fix) -- so it only ever addresses the timing sliver,
  not the "genuine gap" majority case this section just established.
- **Option C (add a repair subcommand, e.g. `edm-state audit-round-repair <PREFIX>`, that re-runs
  the three CA-471 checks against a round already marked `completed_at`, and promotes
  `partial` -> `full` if they now pass):** directly answers "is irreversibility correct". Cost:
  contradicts the double-completion refusal's stated rationale (`:5072-5073`, "may be completed
  only once") unless that refusal is itself narrowed to apply only to the token/cost-recording
  half rather than the round_type determination; needs a decision on whether a human must approve
  a promotion (a round retroactively becoming convergent with no new agent work is exactly the
  kind of gate this methodology otherwise insists a human see).

---

## CA-074 -- the union rule, the missing subtraction, and whether it is live in production today

**Established: the code-level bug is real.** `cmd_audit_round_start`, `bin/edm-state:4996-5005`:

```bash
if [[ -z "$lenses_arg" ]]; then
  lenses_json="$(printf '%s\n' $ALL_LENS_IDS | jq -R . | jq -s .)"   # ALL 14, unconditionally
else
  ...
fi
```

When `--lenses` is omitted, `lenses_json` is materialized to **all 14** lens IDs regardless of
what `--na-lenses` names. `lenses_na_json` is parsed and validated separately (`:5007-5026`,
membership in `CONDITIONAL_LENS_IDS` enforced, currently `{L13}` only -- `:1809`). The union
derivation, `:5038-5042`:

```bash
round_type="$(jq -nr --argjson lenses "$lenses_json" --argjson na "$lenses_na_json" --argjson all "$all_lens_json" '
    (($lenses + $na) | unique | sort) as $union
  | ($all | sort) as $allsorted
  | if $union == $allsorted then "full" else "partial" end
')"
```

never subtracts `na` from `lenses` before or after computing the union -- it only unions them.
Concretely, if `audit-round-start <PREFIX> code --na-lenses L13` is called with `--lenses`
**omitted**: `lenses_json` = all 14 (L13 included), `lenses_na_json` = `["L13"]`. `round_type` still
correctly computes `full` (the union trivially covers `ALL_LENS_IDS` either way), but the **state
record now carries `lenses` containing L13 *and* `lenses_na` containing L13** -- the exact
double-count the finding names.

**Established consequence downstream, by reading `_cmd_audit_round_complete_body` against this
shape:** check (1) (`:5153-5165`) iterates every member of `read_round_lenses($all)` (which, since
`lenses` is non-empty, returns `lenses` verbatim including L13) and requires a landed
`lens-L13.jsonl`. Check (2) (`:5167-5179`) iterates `lenses_na` (`["L13"]`) and requires **no**
`lens-L13.jsonl`. For a round where L13 was correctly never launched (guard D2: L13 is genuinely
N/A on an untyped stack, so no agent runs and no file is written), check (1) fails -- `L13` lands
in `_missing_run` and the round is downgraded to `partial` -- while check (2) passes. **A
legitimately-N/A lens produces a spurious downgrade of an otherwise-complete round**, purely
because it was double-counted at round-start.

**Established: this exact call shape is never exercised in production or in tests.**
`skills/code-audit/SKILL.md:51,58,76` makes the orchestrator's own Step 1 compute `LENS_SET` as
"all 14 lenses **minus** any named in `NA_LENSES`" *before* calling `audit-round-start`, and states
plainly, "`--lenses` is not optional here even on a full round." Every call site in
`bin/tests/wave6-smoke.sh` that passes a valid `--na-lenses` value also passes an explicit
`--lenses` list that already excludes the N/A lens (e.g. `:954,1004,3634,3815,3825,4089,4112` --
all `--lenses L1,...,L12,L14 --na-lenses L13`). Grepped specifically for `audit-round-start
<PREFIX> code --na-lenses` with **no** accompanying `--lenses`: the only hit,
`wave6-smoke.sh:3848`, passes an *invalid* `--na-lenses L8` specifically to test the hard `die` on
an out-of-`CONDITIONAL_LENS_IDS` value -- it never reaches the materialization/union code this
finding is about. **No test exercises `audit-round-start <PREFIX> code --na-lenses L13` with
`--lenses` omitted.**

**Established: EDMV4's own real round-1 state record is consistent with the correct behavior, not
the bug, because the caller (the skill) did the subtraction itself.**
`SRD/.archived/edm/EDMV4__ecc-integration/.edm-state.json:168-185` records `lenses` as exactly 13
members (`L1`-`L12`, `L14`, explicitly **excluding** `L13`) with `lenses_na: ["L13"]`. That shape
proves `--lenses` was passed explicitly with L13 already removed -- i.e., the skill's own Step 1
subtraction ran, not `audit-round-start`'s ALL_LENS_IDS default path. **This is not an accident,
and it is not proof the bug is harmless** -- it is proof the bug is currently masked by exactly one
caller convention (the skill always subtracts and always passes `--lenses` explicitly) that
nothing in `bin/edm-state` enforces or could enforce if a different or future caller (a hand-run
`edm-state audit-round-start ... --na-lenses L13` with no `--lenses`, or a test, or a future skill
revision) ever omits `--lenses` while using `--na-lenses`.

**Open decision:** should `audit-round-start` itself subtract `lenses_na` from a materialized
`lenses`, or is relying on the caller (the skill) sufficient?
- **Option A (fix at the source -- subtract `lenses_na` from the ALL_LENS_IDS materialization,
  and/or `die` on non-disjoint `--lenses`/`--na-lenses`):** matches REMEDIATION.md's own suggested
  fix; makes the invariant hold regardless of caller. Cost: one small jq change plus a new die path
  for the case where an operator hand-passes an overlapping pair; needs a decision on whether
  overlap is a hard `die` (matching the finding's suggested fix) or a silent auto-subtraction
  (quieter, but hides an operator mistake the way the union rule already nearly does).
- **Option B (leave `bin/edm-state` as-is; document that every caller MUST subtract before
  calling, and add a smoke assertion pinning that `skills/code-audit/SKILL.md` still does):**
  cheaper, but leaves the invariant enforced by convention alone -- exactly the shape that already
  produced the CA-007 class of defect elsewhere in this codebase (a documented contract nobody
  mechanically checks). Given `CONDITIONAL_LENS_IDS` has exactly one member today, the blast radius
  of a future violation is currently bounded to a spurious L13-only downgrade -- but that bound is
  not enforced, only currently true by construction.

---

## CA-075 -- marker reconciliation control flow and the GateGuard consequence

**Established: the exact control-flow shape.** `cmd_session_start`, `bin/edm-state:4762-4787`:

```bash
if declare -f edm_marker_path >/dev/null 2>&1; then
  _ss_marker="$(edm_marker_path)"
  if [[ -n "$_ss_marker" ]]; then
    if [[ -f "$_ss_marker" ]]; then                      # <-- marker FILE exists
      ... validate _ss_marker_prefix against _ss_phase6_prefixes ...
      if [[ $_ss_marker_valid -eq 0 ]]; then
        rm -f "$_ss_marker" 2>/dev/null                  # remove the stale marker
        echo "...removed stale Phase-6 marker..."
      fi
      # NOTE: no further branch here -- once inside "marker file exists", the ONLY
      # action possible is remove-if-invalid. There is no recreate arm reachable
      # from this branch, even when _ss_phase6_first_prefix is non-empty.
    elif [[ -n "$_ss_phase6_first_prefix" ]]; then        # <-- marker FILE absent
      _edm_marker_write "$_ss_phase6_first_prefix" "$_ss_phase6_first_dir"
    fi
  fi
fi
```

The removal branch (`:4771-4782`) and the recreate branch (`:4783-4785`) are the `if`/`elif` arms
of the **same** conditional, gated on `[[ -f "$_ss_marker" ]]` -- whether a marker file already
existed on disk at the start of this session-start call. **They are mutually exclusive by
construction.** Concretely: a marker file exists, names a prefix that is stale (not in
`_ss_phase6_prefixes`, e.g. because of a branch switch or because that initiative moved past
phase 6) -- it is removed. If, in the **same** scan, some *other* initiative genuinely is at
`current_phase == 6` (its prefix is in `_ss_phase6_prefixes`, populated at `:4727-4732` during the
loop over every state file), no marker is written for it in this call, because the `elif` that
would write one is never reached -- the `if` branch already fired.

**Confirmed: no lock guards this sequence.** Scanned `:4702-4788` for `with_state_lock` or any
lock acquisition -- none. The scan-then-check-then-delete sequence (list every state file, decide
staleness, `rm -f`) runs unlocked, corroborating the REMEDIATION.md race claim (a `phase-start 6`
landing between the scan and the `rm -f` has its own fresh marker deleted by this same code path,
since `_edm_marker_remove_if_matches` at `:136-147` -- a different function, called from
`phase-start`/elsewhere -- and this reconciliation loop are not mutually exclusive in time).

**Confirmed: the consequence for `edm-gateguard`.** `bin/edm-gateguard:98,102-104`:

```bash
MARKER_PATH="$(edm_marker_path)"

# The allow path: the ONLY filesystem check when no initiative is in Phase 6.
if [[ -z "$MARKER_PATH" ]] || ! test -f "$MARKER_PATH"; then
  exit 0
fi
```

With no marker file present, `edm-gateguard` exits 0 (allow) on line 102-104 for **every**
`Edit`/`Write`/`MultiEdit` call, unconditionally, with zero further checks -- no fact-forcing, no
deny, no denial-budget accounting (that machinery is never reached). This is confirmed directly
from the source, not inferred from `CLAUDE.md`'s description of the "allow path". **Yes: once
CA-075's reconciliation removes a marker without recreating one for a genuinely-active phase-6
initiative, GateGuard allows every edit for the rest of that initiative's Phase 6 -- until
something else writes a fresh marker (the next `phase-start <PREFIX> 6` call, which will not
happen again for an initiative already sitting at phase 6).** There is no other path in
`edm-gateguard` that recreates the marker; only `bin/edm-state`'s `_edm_marker_write` (called from
`cmd_phase_start` and from the recreate arm above) ever writes one.

**Trigger precondition, stated precisely:** this requires a marker file to physically exist and
name a stale prefix (any reason: branch switch, an initiative that progressed past phase 6, a
hand-edited or leftover marker) **at the same moment** a different initiative is genuinely at
phase 6. A repository that has never had two initiatives at phase 6 in overlapping sessions, or
whose stale marker happens to get cleaned up (or overwritten by a fresh `phase-start 6`) before the
next `SessionStart` fires, would not observe this.

**Open decision:** how should reconciliation handle "stale marker present AND a genuinely-active
initiative found in the same scan"?
- **Option A (make removal and recreation independent, not if/elif):** after determining validity,
  always additionally check whether `_ss_phase6_first_prefix` is set and no marker currently
  exists (post-removal) -- write one. Cost: small, localized change to `:4762-4787`; needs a
  decision on what to do if the STALE marker's own prefix is itself still phase-6-valid under a
  race (already covered by `_ss_marker_valid`, so this is a minor edge to specify, not a hard
  problem).
- **Option B (take the state lock around the whole reconciliation block):** closes the
  concurrent-`phase-start`-6 race described above. Orthogonal to Option A -- both can land
  together, or Option A alone leaves the race, or Option B alone leaves the no-recreate gap.
- **Option C (leave as-is, document the gap and rely on GateGuard's own kill-switch/exempt-glob
  knobs as the operator's recovery):** cheapest, but the failure is silent -- nothing on stderr
  tells an operator that Phase 6 fact-forcing quietly stopped for their initiative; discovery
  depends on someone noticing GateGuard never asked for facts.

---

## What I could not establish

- Whether CA-074's masked bug has ever actually fired in a real session (i.e., whether any
  hand-run or scripted invocation outside `skills/code-audit/SKILL.md` has ever called
  `audit-round-start` with `--na-lenses` and no `--lenses`). No such invocation exists in the
  tracked tree; I cannot rule out an untracked or historical one.
- Whether CA-075's race window (a `phase-start 6` landing between the reconciliation's scan and
  its `rm -f`) has ever actually been hit in practice, versus being a theoretical TOCTOU. Requires
  either a reproduction under real concurrency or host telemetry neither of which is available
  from static reading.
- Whether `skills/code-audit/SKILL.md`'s step 8a Glob-count precondition (which narrows, but per my
  reading does not structurally eliminate, the CA-089 race) has ever itself been skipped in a real
  run -- I read the skill's instructions, not a transcript of an actual orchestrator run following
  them.
