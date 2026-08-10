#!/usr/bin/env bash
# timing.sh -- EDMV3-T67 committed timing harness. Reproducible latency/duration measurements for
# the eight edm-state entry points, the linter, and (documented, not driven from here) the CI
# pipeline and eval run budgets named in SRD/edm/EDMV3__prompt-streamline/tickets/epics/
# 11-cross-cutting-delivery.md EDMV3-T67.
#
# Every mode is a REAL measurement against a REAL (generated) fixture -- no numbers are invented.
# Where a budget can only be certified on the reference environment (the pinned CI `test` job
# image on a GitLab shared runner), this script still measures locally and the caller records the
# local figure as "verified-locally-pending-pipeline" rather than faking a CI run.
#
# Usage:
#   bash bin/tests/timing.sh --generate-fixture [--initiatives N] [--dir DIR]
#   bash bin/tests/timing.sh --subcommands   [--dir DIR]
#   bash bin/tests/timing.sh --phase-complete
#   bash bin/tests/timing.sh --ledger        [--findings N]
#   bash bin/tests/timing.sh --session-start
#   bash bin/tests/timing.sh --lint          [--files N] [--lines-per-file N]
#   bash bin/tests/timing.sh --mermaid-ratio
#   bash bin/tests/timing.sh --all-lint      [--dir DIR]
#
# Run from repo root: bash plugins/edm/bin/tests/timing.sh <mode> [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# G21 (round-3): sourced for the shared _HARNESS_PLUGIN_DIR export, so PLUGIN_DIR below is not a
# fifth independent cd/pwd re-derivation of the same plugin root (CA-049). This suite does not
# use _harness.sh's pass/fail counters or assertions -- it is not a *-smoke.sh suite and is not
# discovered by run-all.sh -- only the shared root export.
source "${SCRIPT_DIR}/_harness.sh"
PLUGIN_DIR="$_HARNESS_PLUGIN_DIR"
EDM_STATE="${SCRIPT_DIR}/../edm-state"
EDM_LINT="${SCRIPT_DIR}/../edm-lint-artifacts"

# ---- Sub-second timer (bash 3.2 has no $EPOCHREALTIME). Prefer perl's Time::HiRes when present;
# otherwise fall back to whole-second resolution so Alpine-like images without perl still work --
# CA-158: the fallback must never invent sub-second digits (a prior version added rand(), which
# could return a negative duration and made every reported number noise on a perl-less image).
_now() {
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf("%.6f\n", time())'
  else
    echo "timing.sh: [warn] perl not found -- falling back to whole-second resolution" >&2
    # G31/CA-262: systime() is a gawk/mawk/busybox-awk extension, not POSIX awk -- calling it on
    # the BSD "one true awk" this repo's own supported macOS dev platform ships as /usr/bin/awk
    # aborts this function (and, under this script's `set -e`, the whole script) instead of
    # degrading to whole-second resolution as the comment above promises. Piping `date +%s`
    # through getline is plain POSIX awk and works identically across BSD awk, busybox awk and
    # gawk, so the fallback actually runs on every awk this plugin is exercised against.
    awk 'BEGIN{"date +%s" | getline sec; close("date +%s"); printf "%.6f\n", sec}'
  fi
}

# _ms_between <start> <end> -- integer milliseconds between two _now() readings.
_ms_between() {
  if command -v perl >/dev/null 2>&1; then
    perl -e 'printf("%d\n", ($ARGV[1] - $ARGV[0]) * 1000)' "$1" "$2"
  else
    awk -v start="$1" -v end="$2" 'BEGIN{printf "%d\n", (end - start) * 1000}'
  fi
}

# _p95 <values...> -- integer p95 (nearest-rank) of a list of millisecond integers passed as args.
# G36/CA-196 (round 3): nearest-rank p95 is ceil(0.95*N), not floor(0.95*N) -- the prior
# `int(0.95 * NR)` truncated, so for every sample count this file used at the time (3, 5, or 10)
# the reported "p95" was really a lower percentile (p90 at N=10, p80 at N=5, even the median at
# N=3), systematically discarding the slowest sample and biasing every published latency budget
# optimistic.
# G16/CA-196 (round 4): the ceiling fix alone was not the whole story -- ceil(0.95*N) == N for
# every one of those three sample counts, so the corrected formula still returned the sample
# MAXIMUM, not a real 95th percentile, while the emitted key stayed named p95_ms. N=20 is the
# smallest sample count where ceil(0.95*N) < N (19 < 20), so every sub-second measuring mode below
# now samples ${_P95_SAMPLE_COUNT} runs -- a one-line change per mode, not the nine synchronized
# edits it would have been before G49/CA-280 extracted _measure_p95 (below) to share the loop.
# G14/CA-309 (round 5): "every measuring mode" above means every mode that samples at all --
# --all-lint (a ~60s CI-budget scan, not a sub-second latency probe) deliberately runs
# _measure_p95 with count=1, a single sample, not ${_P95_SAMPLE_COUNT}.
_p95() {
  printf '%s\n' "$@" | sort -n | awk '
    { a[NR] = $1 }
    END {
      if (NR == 0) { print 0; exit }
      idx = int(0.95 * NR)
      if (idx < 0.95 * NR) idx = idx + 1
      if (idx < 1) idx = 1
      if (idx > NR) idx = NR
      print a[idx]
    }'
}

# G49/CA-280: single source for the sample count every measuring mode below uses, so raising it
# again (or lowering it) is a one-line change rather than six synchronized ones.
readonly _P95_SAMPLE_COUNT=20

# _measure_p95 <count> <outvar> -- <cmd...> -- runs <cmd...> <count> times (its own stdout/stderr
# discarded and a non-zero exit tolerated -- these are latency probes, not correctness checks),
# times each run with _now/_ms_between, and writes the nearest-rank p95 (via _p95) into the
# caller's <outvar>. Also stashes the raw per-run millisecond samples into the array
# `<outvar>_samples`, for the call sites that print the raw samples alongside p95.
_measure_p95() {
  local _mp95_n="$1" _mp95_var="$2"
  shift 2
  [[ "${1:-}" == "--" ]] || { echo "timing.sh: _measure_p95 requires a -- before the measured command" >&2; return 2; }
  shift
  local _mp95_samples=() _mp95_i _mp95_t0 _mp95_t1
  for ((_mp95_i = 0; _mp95_i < _mp95_n; _mp95_i++)); do
    _mp95_t0="$(_now)"
    "$@" >/dev/null 2>&1 || true
    _mp95_t1="$(_now)"
    _mp95_samples+=("$(_ms_between "$_mp95_t0" "$_mp95_t1")")
  done
  printf -v "$_mp95_var" '%s' "$(_p95 "${_mp95_samples[@]}")"
  eval "${_mp95_var}_samples=(\"\${_mp95_samples[@]}\")"
}

MODE="${1:-}"
shift || true

DIR=""
N_INITIATIVES=50
N_FINDINGS=500
N_FILES=30
N_LINES_PER_FILE=333

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --initiatives) N_INITIATIVES="$2"; shift 2 ;;
    --findings) N_FINDINGS="$2"; shift 2 ;;
    --files) N_FILES="$2"; shift 2 ;;
    --lines-per-file) N_LINES_PER_FILE="$2"; shift 2 ;;
    *) echo "timing.sh: unknown option '$1'" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  --generate-fixture)
    # AC1/AC7: a reproducible 50-initiative repository so subcommand and --all latency are
    # measured against a fixed, regenerable subject rather than whatever happens to be on disk.
    : "${DIR:=$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-fixture.XXXXXX")}"
    export EDM_SRD_ROOT="${DIR}/SRD"
    mkdir -p "$EDM_SRD_ROOT"
    echo "timing.sh: generating ${N_INITIATIVES} initiatives under ${EDM_SRD_ROOT}"
    for i in $(seq 1 "$N_INITIATIVES"); do
      pfx="$(printf 'TIM%03d' "$i")"
      "$EDM_STATE" init "$pfx" >/dev/null 2>&1 || true
      "$EDM_STATE" approve-gate "$pfx" 1 >/dev/null 2>&1 || true
    done
    echo "timing.sh: fixture ready at ${DIR} (export EDM_SRD_ROOT=${EDM_SRD_ROOT} to reuse it)"
    echo "FIXTURE_DIR=${DIR}"
    ;;

  --subcommands)
    # AC1: get, resolve-dir, branch-check, gate-check under 250ms p95 against the 50-initiative
    # fixture. branch-check/gate-check are expected to exit non-zero off their own git branch --
    # this measures latency, not success, so failures are tolerated with `|| true`.
    [[ -n "$DIR" ]] || { echo "timing.sh --subcommands requires --dir <fixture-dir>" >&2; exit 2; }
    export EDM_SRD_ROOT="${DIR}/SRD"
    pfx="TIM001"
    echo "timing.sh: --subcommands against ${EDM_SRD_ROOT} (prefix ${pfx})"
    for cmd_name in get resolve-dir branch-check gate-check; do
      case "$cmd_name" in
        get)          _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" get "$pfx" ;;
        resolve-dir)  _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" resolve-dir "$pfx" ;;
        branch-check) _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" branch-check "$pfx" ;;
        gate-check)   _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" gate-check "$pfx" srd ;;
      esac
      echo "TIMING subcommand=${cmd_name} p95_ms=${p95} samples_ms=${p95_samples[*]}"
    done
    ;;

  --phase-complete)
    # AC2: phase-complete under 2000ms p95 excluding token-file reading. Measured with no session
    # JSONL fixtures staged (get_session_tokens_since's directory-absent fast path, ~0 tokens
    # read) so the figure isolates the state-mutation cost from token-parsing cost, which is the
    # explicit exclusion this AC states.
    TMP_PC="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-pc.XXXXXX")"
    export EDM_SRD_ROOT="${TMP_PC}/SRD"
    export HOME="${TMP_PC}/home"
    mkdir -p "$EDM_SRD_ROOT" "$HOME"
    "$EDM_STATE" init TIMPC >/dev/null
    "$EDM_STATE" approve-gate TIMPC 1 >/dev/null
    "$EDM_STATE" approve-gate TIMPC 2 >/dev/null
    "$EDM_STATE" approve-gate TIMPC 3 >/dev/null
    # phase-complete only succeeds once per phase-start, so every sample needs its own
    # setup (phase-start, the qc/ artifact phase-complete checks for) and teardown (reset back to
    # phase 6) around the timed call -- _measure_p95's own loop can't own that per-iteration state
    # reset, so it is called here with count=1 per iteration purely to share _now/_ms_between/_p95
    # rather than re-deriving them, and the per-iteration results are pooled into one p95 after.
    samples=()
    for i in $(seq 1 "$_P95_SAMPLE_COUNT"); do
      "$EDM_STATE" phase-start TIMPC 6 >/dev/null 2>&1 || true
      mkdir -p "${EDM_SRD_ROOT}/TIMPC/qc"
      echo "# QC Summary" > "${EDM_SRD_ROOT}/TIMPC/qc/qc-summary.md"
      _measure_p95 1 pc_ms -- "$EDM_STATE" phase-complete TIMPC 6
      samples+=("$pc_ms")
      # Reset for the next sample (phase-complete only succeeds once per phase-start).
      "$EDM_STATE" set TIMPC current_phase 6 >/dev/null 2>&1 || true
    done
    p95="$(_p95 "${samples[@]}")"
    echo "TIMING phase-complete p95_ms=${p95} samples_ms=${samples[*]} (token-file reading excluded: no session JSONL staged)"
    echo "TOKEN_READ_BOUND: get_session_tokens_since caps each session JSONL read at \${EDM_TOKEN_READ_LINE_CAP:-20000} lines (tail -n, EDMV3-T67 AC2)"
    rm -rf "$TMP_PC"
    ;;

  --ledger)
    # AC3: audit-converged under 500ms p95 and render-ledger under 1000ms p95 on a 500-finding
    # ledger. Findings are synthetic but structurally real (same fields cmd_render_ledger and
    # cmd_audit_converged consume), generated deterministically rather than hand-typed.
    TMP_LG="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-ledger.XXXXXX")"
    export EDM_SRD_ROOT="${TMP_LG}/SRD"
    mkdir -p "$EDM_SRD_ROOT"
    "$EDM_STATE" init TIMLEDGER >/dev/null
    init_dir="$("$EDM_STATE" resolve-dir TIMLEDGER)"
    mkdir -p "${init_dir}/code-audit"
    jsonl="${init_dir}/code-audit/findings-ledger.jsonl"
    : > "$jsonl"
    echo "timing.sh: generating ${N_FINDINGS}-finding ledger at ${jsonl}"
    i=1
    while [[ "$i" -le "$N_FINDINGS" ]]; do
      sev_mod=$((i % 4))
      case "$sev_mod" in
        0) sev="P0" ;; 1) sev="P1" ;; 2) sev="P2" ;; *) sev="NOTED" ;;
      esac
      status="open"
      [[ $((i % 5)) -eq 0 ]] && status="fixed"
      printf '{"id":"CA-%04d","sev":"%s","status":"%s","lenses":["L1"],"component":"src/mod%d.js","title":"synthetic finding %d","raised_round":1,"resolved_round":null}\n' \
        "$i" "$sev" "$status" "$((i % 20))" "$i" >> "$jsonl"
      i=$((i + 1))
    done
    _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" audit-converged TIMLEDGER
    echo "TIMING audit-converged p95_ms=${p95} samples_ms=${p95_samples[*]} (${N_FINDINGS} findings)"
    _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_STATE" render-ledger TIMLEDGER
    echo "TIMING render-ledger p95_ms=${p95} samples_ms=${p95_samples[*]} (${N_FINDINGS} findings)"
    rm -rf "$TMP_LG"
    ;;

  --session-start)
    # AC4: check_permission_rules() reads at most three small files and adds under 50ms to
    # session-start. Measured as the delta between session-start with the permission-ask rule
    # files present vs. absent, isolating the check's own overhead from the rest of session-start.
    TMP_SS="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-ss.XXXXXX")"
    export EDM_SRD_ROOT="${TMP_SS}/SRD"
    mkdir -p "$EDM_SRD_ROOT" "${TMP_SS}/.claude"
    "$EDM_STATE" init TIMSS >/dev/null
    _ss_probe() { ( cd "$TMP_SS" && "$EDM_STATE" session-start ); }
    _measure_p95 "$_P95_SAMPLE_COUNT" p95_without -- _ss_probe
    printf '{"permissions":{"ask":["Bash(edm-state approve-gate*)","Bash(edm-state archive*)"]}}\n' \
      > "${TMP_SS}/.claude/settings.local.json"
    _measure_p95 "$_P95_SAMPLE_COUNT" p95_with -- _ss_probe
    delta=$((p95_with - p95_without))
    echo "TIMING session-start without_permission_files_p95_ms=${p95_without} with_permission_files_p95_ms=${p95_with} delta_ms=${delta}"
    rm -rf "$TMP_SS"
    ;;

  --lint)
    # AC5: full lint of a typical initiative directory (30 .md files, 10,000 total lines) under
    # 3000ms. Files are generated at N_LINES_PER_FILE lines each (default 333 * 30 ~= 10,000).
    TMP_LINT="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-lint.XXXXXX")"
    export EDM_SRD_ROOT="${TMP_LINT}/SRD"
    mkdir -p "${EDM_SRD_ROOT}/TIMLINT"
    "$EDM_STATE" init TIMLINT >/dev/null
    for f in $(seq 1 "$N_FILES"); do
      target="${EDM_SRD_ROOT}/TIMLINT/fixture-${f}.md"
      : > "$target"
      for l in $(seq 1 "$N_LINES_PER_FILE"); do
        echo "Line ${l} of fixture file ${f} -- ordinary ASCII prose content for lint timing." >> "$target"
      done
    done
    total_lines="$(cat "${EDM_SRD_ROOT}/TIMLINT"/fixture-*.md | wc -l | tr -d ' ')"
    _measure_p95 "$_P95_SAMPLE_COUNT" p95 -- "$EDM_LINT" TIMLINT
    echo "TIMING lint p95_ms=${p95} samples_ms=${p95_samples[*]} (${N_FILES} files, ${total_lines} total lines)"
    rm -rf "$TMP_LINT"
    ;;

  --mermaid-ratio)
    # AC6 (cross-check, T43 AC10 owns the original measurement): re-take the ratio of lint time
    # with the Mermaid class vs. an equivalent fixture set with no ```mermaid fences, on this
    # environment. This fixture is the WORST realistic case, not the best one: every single file
    # gets exactly one small mermaid fence appended below (see the loop a few lines down), so the
    # no-fence short-circuit (T43) that would keep the ratio near 1.0x for a corpus with few or no
    # diagrams is deliberately NOT exercised here -- this mode measures the per-line Mermaid scan
    # cost on every file, not the short-circuit's savings on a mixed corpus. The mode reports the
    # measured ratio against the actual printed budget (see below, "<= 1.40x"), not an assumed
    # near-1.0x number; CHANGELOG.md separately records a real 1.19x sample from this same mode.
    TMP_MR="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-mermaid.XXXXXX")"
    export EDM_SRD_ROOT="${TMP_MR}/SRD"
    mkdir -p "${EDM_SRD_ROOT}/TIMMR"
    "$EDM_STATE" init TIMMR >/dev/null
    for f in $(seq 1 "$N_FILES"); do
      target="${EDM_SRD_ROOT}/TIMMR/fixture-${f}.md"
      : > "$target"
      for l in $(seq 1 "$N_LINES_PER_FILE"); do
        echo "Line ${l} of fixture file ${f} -- ordinary ASCII prose content, no diagrams." >> "$target"
      done
    done
    _measure_p95 "$_P95_SAMPLE_COUNT" p95_base -- "$EDM_LINT" TIMMR
    # Add one small mermaid fence per file (a realistic ratio: most files carry zero or one).
    for f in $(seq 1 "$N_FILES"); do
      target="${EDM_SRD_ROOT}/TIMMR/fixture-${f}.md"
      { echo '```mermaid'; echo 'flowchart TD'; echo '    A[Start] --> B[End]'; echo '```'; } >> "$target"
    done
    _measure_p95 "$_P95_SAMPLE_COUNT" p95_mermaid -- "$EDM_LINT" TIMMR
    # G37/CA-197: when either p95 measures 0ms (routine on the perl-less whole-second-resolution
    # fallback, or on a fast host), the prior `b/(a>0?a:1)` silently substituted a raw millisecond
    # count as if it were a meaningful ratio -- which can look like a huge false budget breach.
    # Refuse instead of reporting a fabricated number.
    if [[ "$p95_base" -le 0 || "$p95_mermaid" -le 0 ]]; then
      echo "TIMING mermaid_ratio baseline_p95_ms=${p95_base} with_mermaid_p95_ms=${p95_mermaid} ratio=UNMEASURABLE (timer resolution too coarse -- install perl, or raise --files/--lines-per-file until both baselines exceed 0 ms)" >&2
      rm -rf "$TMP_MR"
      exit 3
    fi
    # CA-084/CA-158: no perl dependency here -- awk is already required by --lint's own callers.
    ratio="$(awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/a}')"
    echo "TIMING mermaid_ratio baseline_p95_ms=${p95_base} with_mermaid_p95_ms=${p95_mermaid} ratio=${ratio}x (budget: <= 1.40x)"
    rm -rf "$TMP_MR"
    ;;

  --all-lint)
    # AC7: `edm-lint-artifacts --all` over the fixture repository under 60000ms, a CI budget
    # rather than a commit-path budget. --all-lint takes --dir and derives nothing else from it
    # (no --initiatives flag exists on this mode), so the initiative count reported below is
    # counted from the fixture at measurement time via the same resolver edm-lint-artifacts
    # itself uses (`edm-state list --paths`), never assumed from N_INITIATIVES -- that constant
    # is only ever set by --generate-fixture's own --initiatives flag and would silently misreport
    # if this mode were pointed at a differently-sized fixture (CA-073).
    [[ -n "$DIR" ]] || { echo "timing.sh --all-lint requires --dir <fixture-dir>" >&2; exit 2; }
    export EDM_SRD_ROOT="${DIR}/SRD"
    # G14/CA-309 (round 5): route through _measure_p95, the same as every other mode, rather
    # than a hand-rolled _now/_ms_between pair -- this was the last surviving hand-rolled
    # timing loop in the file, and being the one working template left is exactly how a
    # contributor adding a future mode would find and copy it, regenerating the class.
    # Deliberately count=1 (a single-sample CI budget check, not a p95 latency probe): a 60s
    # `--all` scan is not something this harness re-runs 20 times per invocation, unlike the
    # sub-second modes above. The emitted key stays `duration_ms`, not `p95_ms`, since a single
    # sample has no percentile to report.
    actual_initiatives="$("$EDM_STATE" list --paths 2>/dev/null | grep -c . || true)"
    _measure_p95 1 ms -- "$EDM_LINT" --all
    echo "TIMING all_lint duration_ms=${ms} (${actual_initiatives} initiatives, budget <= 60000ms, CI budget not a commit-path budget)"
    ;;

  *)
    echo "usage: timing.sh <--generate-fixture|--subcommands|--phase-complete|--ledger|--session-start|--lint|--mermaid-ratio|--all-lint> [options]" >&2
    exit 2
    ;;
esac
