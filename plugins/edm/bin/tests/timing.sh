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
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/.." && cd .. && pwd)"
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
    awk 'BEGIN{srand(); printf "%.6f\n", systime()}'
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
_p95() {
  printf '%s\n' "$@" | sort -n | awk '
    { a[NR] = $1 }
    END {
      if (NR == 0) { print 0; exit }
      idx = int(0.95 * NR)
      if (idx < 1) idx = 1
      if (idx > NR) idx = NR
      print a[idx]
    }'
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
      samples=()
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        t0="$(_now)"
        case "$cmd_name" in
          get)           "$EDM_STATE" get "$pfx" >/dev/null 2>&1 || true ;;
          resolve-dir)   "$EDM_STATE" resolve-dir "$pfx" >/dev/null 2>&1 || true ;;
          branch-check)  "$EDM_STATE" branch-check "$pfx" >/dev/null 2>&1 || true ;;
          gate-check)    "$EDM_STATE" gate-check "$pfx" srd >/dev/null 2>&1 || true ;;
        esac
        t1="$(_now)"
        samples+=("$(_ms_between "$t0" "$t1")")
      done
      p95="$(_p95 "${samples[@]}")"
      echo "TIMING subcommand=${cmd_name} p95_ms=${p95} samples_ms=${samples[*]}"
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
    samples=()
    for i in 1 2 3 4 5; do
      "$EDM_STATE" phase-start TIMPC 6 >/dev/null 2>&1 || true
      mkdir -p "${EDM_SRD_ROOT}/TIMPC/qc"
      echo "# QC Summary" > "${EDM_SRD_ROOT}/TIMPC/qc/qc-summary.md"
      t0="$(_now)"
      "$EDM_STATE" phase-complete TIMPC 6 >/dev/null 2>&1 || true
      t1="$(_now)"
      samples+=("$(_ms_between "$t0" "$t1")")
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
    samples=()
    for _ in 1 2 3 4 5; do
      t0="$(_now)"
      "$EDM_STATE" audit-converged TIMLEDGER >/dev/null 2>&1 || true
      t1="$(_now)"
      samples+=("$(_ms_between "$t0" "$t1")")
    done
    p95="$(_p95 "${samples[@]}")"
    echo "TIMING audit-converged p95_ms=${p95} samples_ms=${samples[*]} (${N_FINDINGS} findings)"
    samples=()
    for _ in 1 2 3 4 5; do
      t0="$(_now)"
      "$EDM_STATE" render-ledger TIMLEDGER >/dev/null 2>&1 || true
      t1="$(_now)"
      samples+=("$(_ms_between "$t0" "$t1")")
    done
    p95="$(_p95 "${samples[@]}")"
    echo "TIMING render-ledger p95_ms=${p95} samples_ms=${samples[*]} (${N_FINDINGS} findings)"
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
    samples_without=()
    for _ in 1 2 3 4 5; do
      t0="$(_now)"
      ( cd "$TMP_SS" && "$EDM_STATE" session-start >/dev/null 2>&1 ) || true
      t1="$(_now)"
      samples_without+=("$(_ms_between "$t0" "$t1")")
    done
    printf '{"permissions":{"ask":["Bash(edm-state approve-gate*)","Bash(edm-state archive*)"]}}\n' \
      > "${TMP_SS}/.claude/settings.local.json"
    samples_with=()
    for _ in 1 2 3 4 5; do
      t0="$(_now)"
      ( cd "$TMP_SS" && "$EDM_STATE" session-start >/dev/null 2>&1 ) || true
      t1="$(_now)"
      samples_with+=("$(_ms_between "$t0" "$t1")")
    done
    p95_without="$(_p95 "${samples_without[@]}")"
    p95_with="$(_p95 "${samples_with[@]}")"
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
    samples=()
    for _ in 1 2 3; do
      t0="$(_now)"
      "$EDM_LINT" TIMLINT >/dev/null 2>&1 || true
      t1="$(_now)"
      samples+=("$(_ms_between "$t0" "$t1")")
    done
    p95="$(_p95 "${samples[@]}")"
    echo "TIMING lint p95_ms=${p95} samples_ms=${samples[*]} (${N_FILES} files, ${total_lines} total lines)"
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
    samples_base=()
    for _ in 1 2 3; do
      t0="$(_now)"; "$EDM_LINT" TIMMR >/dev/null 2>&1 || true; t1="$(_now)"
      samples_base+=("$(_ms_between "$t0" "$t1")")
    done
    p95_base="$(_p95 "${samples_base[@]}")"
    # Add one small mermaid fence per file (a realistic ratio: most files carry zero or one).
    for f in $(seq 1 "$N_FILES"); do
      target="${EDM_SRD_ROOT}/TIMMR/fixture-${f}.md"
      { echo '```mermaid'; echo 'flowchart TD'; echo '    A[Start] --> B[End]'; echo '```'; } >> "$target"
    done
    samples_mermaid=()
    for _ in 1 2 3; do
      t0="$(_now)"; "$EDM_LINT" TIMMR >/dev/null 2>&1 || true; t1="$(_now)"
      samples_mermaid+=("$(_ms_between "$t0" "$t1")")
    done
    p95_mermaid="$(_p95 "${samples_mermaid[@]}")"
    # CA-084/CA-158: no perl dependency here -- awk is already required by --lint's own callers.
    ratio="$(awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/(a>0?a:1)}')"
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
    actual_initiatives="$("$EDM_STATE" list --paths 2>/dev/null | grep -c . || true)"
    actual_initiatives="${actual_initiatives:-0}"
    t0="$(_now)"
    "$EDM_LINT" --all >/dev/null 2>&1 || true
    t1="$(_now)"
    ms="$(_ms_between "$t0" "$t1")"
    echo "TIMING all_lint duration_ms=${ms} (${actual_initiatives} initiatives, budget <= 60000ms, CI budget not a commit-path budget)"
    ;;

  *)
    echo "usage: timing.sh <--generate-fixture|--subcommands|--phase-complete|--ledger|--session-start|--lint|--mermaid-ratio|--all-lint> [options]" >&2
    exit 2
    ;;
esac
