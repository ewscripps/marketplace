# Lens L7 -- Cross-File Consistency (Round 7)

**Tooling note (CA-130's class):** Write absent from this lens's delivered runtime
tool set (7+ consecutive rounds). This report was transcribed by the orchestrator
from the lens agent's final message, after two stalled attempts before it.

**Coverage caveat:** this round's L7 sweep is narrower than a full pass. What is
reported below is grounded in `plugins/edm/hooks/hooks.json` read in full, a
prefix-validator sweep across `bin/edm-*`, and `plugins/edm/CLAUDE.md` as the
authority for documented intent. No re-sweep of `skills/` vs `skills/` or
`agents/` vs `agents/` sibling groups this round.

## Findings (L7: Cross-File Consistency)

### P1-1 -- The git-commit hook re-implements `srd_root` normalization inline in JSON, outside every shell linter's reach

- **A:** `plugins/edm/hooks/hooks.json` line 86 (`PreToolUse` / `git commit`)
- **B:** `plugins/edm/bin/edm-lint-artifacts` and `plugins/edm/bin/edm-state`, which own `EDM_SRD_ROOT` handling

Every other hook in the file is a one-line delegation to `edm-state`. This one
carries roughly 2,000 characters of shell: explicit-vs-default `srd_root`
detection, a `./`-stripping loop, absolute-path relativization against
`git rev-parse --show-toplevel`, a trailing-slash / `.`-suffix trim loop,
`..`-traversal rejection, a staged-path `awk` prefix extractor, and a per-prefix
resolve-then-lint loop with exit-code mapping.

Why consistency matters here: CI's `lint:bash-syntax` and `lint:shellcheck` both
scope to `bin/*`, `bin/tests/*.sh`, and `evals/*.sh`. Neither reads
`hooks/hooks.json`. So the most complex shell in the plugin is the only shell in
the plugin that no linter checks -- and it is JSON-escaped, so a quoting error is
also the hardest to catch by eye in review. It is additionally a copy-pasted
variant of srd_root logic the `bin/` helpers already own, which is the classic
"Module A uses the shared utility, Module B has its own copy" divergence.

**Fix:** extract to `bin/edm-lint-staged-artifacts` (or an `edm-state
lint-staged` subcommand) and reduce the hook to the same shape as its five
siblings: `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0;
edm-lint-staged-artifacts`. That brings it under both linters, makes it testable
from `bin/tests/`, and lets it share one srd_root normalizer with
`edm-lint-artifacts`.

### P2-1 -- The two layers of each gate hook disagree on the blocking predicate

- **A:** command hooks, `hooks.json` lines 19, 32, 45, 58, 71 -- `edm-state
  gate-check "$prefix" <gate>; ec=$?; if [ "$ec" -eq 3 ]; then exit 2; fi; exit 0`
- **B:** paired prompt hooks, lines 23, 36, 49, 62, 75 -- "If it exits non-zero,
  BLOCK the expansion"

The deterministic layer blocks on exit code **3 only**; the advisory layer is
instructed to block on **any** non-zero. For any `gate-check` non-zero exit that
is not 3 (internal error, usage error, `jq` failure), the two layers reach
opposite verdicts. The prompt's own preamble asserts "The command hook running
alongside this prompt already enforces this deterministically -- this prompt is
an advisory second layer, not the primary check," which only holds if both share
a predicate.

`CLAUDE.md Sec."Hooks behavior"` states the intended contract exactly ("an
invalid prefix argument or an actual `edm-state gate-check` refusal exits 2,
blocking... a setup condition never does"). The command hook implements it; the
prompt text does not.

**Fix:** in all five prompt entries, replace "If it exits non-zero" with the
exit-3 predicate, plus an explicit "any other non-zero exit is a setup condition
-- allow expansion and surface the diagnostic."

### P2-2 -- The two layers use divergent procedures to decide "legitimate first invocation"

Same five hook pairs. The command hook never calls `resolve-dir`; it relies on
`gate-check` returning non-3 for a prefix with no state file yet. The prompt hook
re-derives the same predicate independently, running `edm-state resolve-dir
<PREFIX>` as its step 3 and allowing on failure.

Two implementations of one predicate that can drift apart: if `gate-check`'s
handling of an unresolvable prefix ever changes, only the command layer follows
and the prompt layer silently keeps the old semantics.

**Fix:** have the prompt defer to the command hook's exit code rather than
re-deriving with `resolve-dir`, or add the `resolve-dir` precheck to the command
hook so both layers read the same signal.

### P2-3 -- Prefix character class: the commit hook is uppercase-only, nine other validators accept mixed case

- **A:** `hooks.json` line 86 -- `grep -E '^[A-Z][A-Z0-9_-]*$'`, reinforced by
  the awk guard `parts[1] ~ /^[A-Z]/`
- **B:** `bin/edm-state:222` (`state_file_for`), `:261`, `:263`, `:3410`,
  `:3411`, `:3415`, `bin/edm-init:74`, and all five `UserPromptExpansion`
  command hooks -- all `^[A-Za-z0-9_-]+$`

The divergence fails **open**, which is the worse direction: an initiative whose
PREFIX contains a lowercase character is accepted by `edm-init` and resolves fine
through `state_file_for`, but the commit hook's `grep -E` filter drops it,
`prefixes` comes up empty, the hook exits 0, and commit-path artifact lint
silently never runs for that initiative. The failure mode is "enforcement absent
without a diagnostic," not "commit rejected."

Direction to normalize is genuinely ambiguous: `CLAUDE.md` documents PREFIX as
"3-6 uppercase characters" validated by `bin/edm-validate-prefix`, so
uppercase-only may be the intended convention -- in which case the nine
mixed-case sites are the divergent ones and the convention is enforced at 1 of
10 sites. Either way, all ten should agree. `bin/edm-validate-prefix`'s own
regex was not read this round (it did not match the sweep pattern); confirm it
before picking a direction.

### P2-4 -- The auto-spawned QC path ignores `qc_shard_threshold` that the skill path honors

`hooks.json` lines 113-118 (`SubagentStop` / `edm-implementer`) instructs the
spawned `edm-qc-auditor` to write to `<initiative-dir>/qc/qc-summary.md` with no
mention of sharding. `CLAUDE.md` documents `qc/qc-shard-{NN}.md` for the case
where ticket count exceeds `qc_shard_threshold` (default 20). So the
hook-triggered QC entry point always produces a single unsharded summary
regardless of that userConfig key, while the `/edm:implement` path presumably
honors it -- same operation, two call sites, one honors a config key the other
does not.

**Fix:** either have the hook prompt reference the sharding rule (or the skill
section that owns it) rather than naming one filename, or state in `CLAUDE.md`
that the auto-spawn path is deliberately unsharded and why. Confirm against
`skills/implement/SKILL.md`, which was not read this round.

### P2-5 -- `SubagentStop` prompt references `<PREFIX>` with no derivation instruction

All five `UserPromptExpansion` prompts open with an explicit extraction step
("Extract the initiative PREFIX from the first argument") because `$ARGUMENTS`
is available there. The `SubagentStop` prompt (line 117) jumps straight to
"Resolve the initiative directory from state using `edm-state resolve-dir
<PREFIX>`" -- but `SubagentStop` carries no `$ARGUMENTS`, and the prompt never
says where PREFIX comes from. Its sibling prompts in the same file all do.

**Fix:** add the derivation step (from the parent conversation's active
initiative, or via `edm-state active-initiatives`), matching the explicitness of
the five gate prompts.

Also unverified and worth a spot-check: line 117 uses `edm-state
record-partial-verdict <PREFIX> <ticket> PARTIAL '<note>'`, whereas `CLAUDE.md`
documents the closure form as `record-partial-verdict <PREFIX> <ticket> close
<PASS|FAIL> <ref>`. Plausibly both an open form and a close form exist, but this
was not confirmed against `bin/edm-state` this round.

## Noted / Not Actionable

- **`SessionStart`/`Stop`/`PreCompact` use `cmd && cmd2 || true`; gate hooks use
  `command -v ... || exit 0;`** -- two idioms for the same "skip if binary
  absent" concern, but justified: `|| true` is correct for fire-and-forget
  checkpointing (never block a session on a checkpoint failure), and the
  guard-and-exit form is required where a subsequent exit code is load-bearing.
- **`Stop` and `PreCompact` command strings are byte-identical** -- intentional
  duplication (two events, one intent), not drift.
- **The five `UserPromptExpansion` command hooks are byte-identical except the
  gate-name argument** -- this is the consistency you want. The gate *number*
  is resolved by `gate-check` from mode and `skipped_phases` rather than
  hardcoded per matcher, and the prompt text explicitly forbids hardcoding it.
  Exemplary; leave alone.
- **`edm:implement`'s prompt carries one extra clause its four siblings lack**
  ("and also enforces Gate 3.5 when `compliance_enabled=true`") -- justified;
  Gate 3.5 only sits before Phase 6.
- **`SubagentStop` has a prompt layer but no command layer, unlike the gate
  hooks' two-layer design** -- a command hook cannot spawn an agent, so
  prompt-only is forced.
- **`[EDM] ` stderr prefix** is used uniformly across all seven diagnostics in
  the file.
- **PreToolUse exits 1 for a config error (non-blocking) while
  UserPromptExpansion exits 2 for a bad argument (blocking)** -- same broad
  category of user error, opposite blocking outcomes, but both contracts are
  spelled out in `CLAUDE.md Sec."Hooks behavior"` and the asymmetry is
  defensible: blocking a gate expansion is cheap and recoverable, blocking a
  human's commit over a plugin misconfiguration is hostile.
- **`edm-lint-artifacts` exit 1 -> hook exit 2 (block) vs exit 2 -> hook exit 0
  (report only)** -- documented in `CLAUDE.md` and tagged CA-011; the two-tier
  mapping is deliberate.
</content>
