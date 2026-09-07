# Orchestrator notes -- pass 1, 2026-09-04

Verification the orchestrator performed on lens findings before synthesis. The synthesizer should
weigh these alongside the lens reports themselves.

## L2-001 -- corroboration is invalid, core finding survives

L2 reported `plugins/edm/hooks/hooks.json`'s `PreToolUse` block with `"matcher": "git commit"` as
dead registration (P1), citing as corroboration `plugins/edm/CLAUDE.md`'s admission that "Em
dashes have in fact landed in `skills/` and `agents/` and survived there undetected".

**That corroboration does not hold.** The same CLAUDE.md passage gives a different, documented
cause two lines earlier: the git-commit hook runs prefix mode, which never reaches
`plugins/edm/skills/`, `plugins/edm/agents/`, `plugins/edm/docs/`, `plugins/edm/evals/`,
`CLAUDE.md` or `README.md`. A separate, independently documented gap also applies -- `collect_md_files`
filters to `-name '*.md'`, so `bin/` helpers are never collected in any mode. Surviving em dashes
are fully explained by reach, with no need for the hook to be misfiring.

**The core finding still stands on its own evidence**, which the orchestrator verified directly:
the two sibling `PreToolUse` blocks in the same file match on tool names (`Edit|Write|MultiEdit`
and `Bash`), while this block matches on `git commit`, which is not a tool name. That internal
inconsistency is the argument; the em-dash evidence should be dropped from the finding rather
than carried into the ledger, and the severity re-derived without it.

Not yet established either way: whether this host's Claude Code build accepts a bare
`"git commit"` PreToolUse matcher. Confirming it requires observing the hook fire, which this
session cannot do -- neither `/plugin update` nor `/reload-plugins` reads the working tree
(`EDMV4-62`). Treat the reachability claim as unverified-at-runtime, like the six D44 tickets.

## L5 -- confirmed by direct check

L5's headline (three surviving instances of the `.tXX-grants.err` leak shape at
`wave8-smoke.sh:1052`, `:1148`, `:4976`) was verified by the orchestrator: all three exist as
described, and `git check-ignore` confirms none of `.t26/.t27/.t28-grants.err` is ignored. The
fourth instance of the same shape was found and fixed during Phase 6, which makes this a
class recurrence, not a first sighting.

## Round context

Lens agents run at `maxTurns: 30` (pinned by VERIF-T09 AC3). Against a 131-file, 12282-insertion
diff every lens in this round hit that ceiling at least once and required resumption. Lenses that
opened by surveying the tree produced no output in their first budget; lenses that wrote findings
incrementally banked them. This is a measurable capacity mismatch, not a per-agent failure --
`EDMV4-61` retuned `edm-implementer` to 200 and `edm-qc-auditor` to 150 against measured usage,
but the fourteen lens agents were never re-measured.

## L11-002 / L6-010 -- the manifest gap: verified, mechanism partly unconfirmed

Two lenses reached this independently (L6 as a side-effect of checking whether the `[3.3.0]`
CHANGELOG entry told the truth; L11 as its headline P0). The orchestrator verified the fact
directly:

- `.claude-plugin/marketplace.json` lists **12** `edm-audit-*` agents; **15** exist on disk.
- Absent: `edm-audit-silent-failures` (L12), `edm-audit-type-design` (L13),
  `edm-audit-behavioral-tests` (L14) -- exactly this initiative's scope-item-4.4 deliverable.
- `plugins/edm/.claude-plugin/plugin.json` carries no `agents` array at all.
- Across the whole marketplace, **`edm` is the only plugin whose listed count disagrees with its
  disk count**: `release-notes` lists 3 for 3; `web-cms` lists none and ships 13; the rest ship none.

**Confirmed by the orchestrator**: the three files are unlisted while their twelve siblings are
listed, in the only plugin in the repository with that inconsistency.

**NOT independently confirmed by the orchestrator**: L11's mechanism -- that a present `agents`
array *replaces* the default `agents/` directory scan rather than adding to it, quoting "Custom
agent files (replaces default `agents/`)". That semantics is what makes the finding P0 rather than
P2, because under it the three files never load at all. It could not be tested here: this session
runs the cached 3.2.2 plugin, which predates all three agents, so their absence from the session
toolset is equally explained by `EDMV4-62` and proves nothing either way. `web-cms` shipping 13
agents with no `agents` field is consistent with a default scan existing, but does not settle
whether declaring the field suppresses it.

The synthesizer should treat the inconsistency as established and the P0 severity as resting on an
unverified schema claim. Both candidate fixes are cheap and make the question moot: replace the
enumeration with `"agents": ["./agents/"]`, or add the three missing paths.

**Why nothing caught it**: no smoke assertion reads `marketplace.json`'s `agents` array. The
suites assert that file's `version` and its `skills` array length, and `wave8-smoke.sh` counts
agent files **on disk**, not in the manifest. `edm-check-vocabulary` is the only automated reach
into the file and it checks vocabulary, not registration.

## Wave 4 and wave 5 QC were never run -- found by L9, confirmed

`qc/` holds ten shards, `w01` through `w03`, and `qc-summary.md`'s sentinel reads
`wave=03 shards=10 tickets=39`. Waves 4 and 5 drained with no QC pass, so eleven tickets were
merged and Phase 6 was closed with no acceptance-criteria verification: `T14`, `T15`, `T26`,
`T45`, `T56`, `T57` (wave 4) and `T28`, `T50`, `T51`, `T52`, `T53` (wave 5) -- including all four
Definition-of-Done tickets.

This is an orchestrator failure, not an agent one, and it is a recurrence of the exact class
`EDMV4-61`/`T55` AC5 was written to prevent: the post-wave shard count was run after wave 3 and
not repeated. Shards `w04-01` and `w05-01` were commissioned on discovery and are running.

## Adjudications the orchestrator made between disagreeing lenses

**`EDM_GATEGUARD_MAX_DENIALS` -- L1 is right, L12's NOTED is wrong.** L1-002 files it P1
(fail-open); L12 files it NOTED on the grounds that it is "verified loud under `set -u`". The
orchestrator tested it directly:

    EDM_GATEGUARD_MAX_DENIALS=none; [[ "0" -ge "$EDM_GATEGUARD_MAX_DENIALS" ]]   -> TRUE

`set -u` fires on an *unset* variable. A variable that is set to a non-numeric string is not
unset, so `-u` never triggers; bash's arithmetic context evaluates `none` as 0 and `0 -ge 0` is
true at zero denials. `bin/edm-gateguard:222` reads the value with a `:-3` default only, and
`:348` compares it arithmetically with no `to_int()` and no regex guard, while `bin/edm-state:167`
already ships `to_int()` for exactly this. Treat as P1. L12's NOTED should be dropped rather than
merged as a competing view.

**`detect-conditional-lenses` (L12-001) -- defect confirmed, this round unaffected.** The
orchestrator verified that `git ls-files` for this repository returns **no** typed-stack marker at
any depth (root or nested), so `L13` is genuinely N/A here and this round's `13 run + 1 N/A = 14 =
full` classification is sound. The defect L12 reproduced is nonetheless real and unrelated to this
repo's outcome: `bin/edm-state:1725-1728` matches markers with `grep -qx 'tsconfig.json'`, which
only matches a root-level path, so a monorepo with `packages/app/tsconfig.json` is wrongly scored
N/A. Severity should reflect that a wrong N/A is not a skipped lens but an *affirmatively
required* absence -- `audit-round-complete`'s check (2) demands `lens-L13.jsonl` be missing -- so
the round still converges and archives.

**wave7's SIGINT case -- L3 corrected the orchestrator, not the other way round.** The briefing
told L3 the `|| true` guard meant the test "silently verifies nothing". That was wrong and L3 said
so: when the signal misses, the child completes normally and both assertions FAIL loudly. The
orchestrator observed exactly those two failures earlier in this session while running the suite
under `nohup`. The swallowed error is the failed `kill`, not the verdict. The real defect is
narrower: the case is only green where a controlling terminal exists.

**`record-partial-verdict` locking -- L3 corrected the briefing.** It does hold the lock across
the full read-modify-write (`bin/edm-state:5297`, CA-059). The residual L3 filed is contention and
a timed-out auditor's PARTIAL never reaching `partial_verdict_map`, not lock scope.
