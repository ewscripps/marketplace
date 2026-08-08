#!/usr/bin/env bash
# EDM-HELP-BEGIN
# tiering-matrix.sh -- mechanical model/effort promotion rule for the contested-agent set
# (EDMV3-T48, D16). This script does not run the eval fixture and does not invoke `claude` --
# it consumes a JSON manifest of already-captured per-agent, per-configuration finding counts
# and cost, and applies D16's promotion rule mechanically, exactly the way bin/edm-compare-eval
# consumes an already-produced scores.json rather than running the eval itself. Producing a
# real manifest requires the wave-A eval baseline (evals/baseline/scores.json), which does not
# exist yet -- see decisions.md D26. This script is built and unit-verified against synthetic
# fixtures now, and is what closes D26 once a baseline exists.
#
# Usage:
#   tiering-matrix.sh <manifest.json>   Apply the promotion rule to <manifest.json>, print the
#                                       per-agent, per-configuration table and each agent's
#                                       decision line. Exit 0 once the table is produced --
#                                       "no qualifying cheaper config, unchanged" is a valid,
#                                       non-error outcome, not a failure.
#   tiering-matrix.sh --self-test      Run the promotion rule against three hand-built synthetic
#                                      agents covering the three logic branches D16 requires:
#                                      (1) a qualifying cheaper config wins, (2) a config missing
#                                      a baseline P0/P1 finding is disqualified and the next
#                                      tier is tried, (3) no candidate qualifies and the agent
#                                      is left unchanged. Exits 0 iff all three assertions hold.
#   tiering-matrix.sh -h|--help        Show this help.
#
# Manifest schema (see evals/README.md "Tiering matrix manifest" for the full description):
#   {
#     "agents": [
#       {
#         "agent": "<agent-name>",
#         "baseline": {"total_findings": N, "findings": ["P0-1", "P1-1", ...], "cost_usd": N},
#         "results": [
#           {"model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": N,
#            "findings": [...], "cost_usd": N},
#           {"model": "opus", "effort": "high", "tier_rank": 2, "total_findings": N,
#            "findings": [...], "cost_usd": N}
#         ]
#       }
#     ]
#   }
#
# `findings` entries are severity-prefixed IDs ("P0-<n>", "P1-<n>", "P2-<n>", "NOTED-<n>") so
# the P0/P1 recall check compares specific findings, not just a count -- a candidate that finds
# a different P0 than the baseline found is still a miss, even if the counts happen to match.
# `tier_rank` orders candidate configurations from cheapest (1) to most expensive; the baseline
# (opus/max) is never itself a candidate row -- it is the fallback when nothing qualifies.
#
# The promotion rule (D16, mechanical, no judgment call):
#   1. Evaluate candidate configurations in ascending tier_rank order (cheapest first).
#   2. A configuration DISQUALIFIES outright if it is missing even one baseline P0 or P1
#      finding (a strict superset check on finding IDs, not a count comparison).
#   3. A configuration that is not disqualified QUALIFIES only if its total findings are
#      >= 80% of the baseline's total findings.
#   4. The first (cheapest) qualifying configuration in tier order wins and is written to the
#      agent's frontmatter.
#   5. If no candidate configuration qualifies, the agent keeps opus/max -- unchanged.
#
# Exit codes: 0 = table produced (or --self-test passed); 1 = --self-test failed one or more
# assertions; 2 = usage or environment error (missing jq, missing/malformed manifest file).
# EDM-HELP-END
# CA-074: -e is intentionally omitted -- --self-test's three assertions each capture run_matrix's
# own failure with an explicit `|| { ...; return 1; }` so a failing assertion reports a clean
# "self-test: FAIL" line naming which of the three branches broke, rather than -e aborting the
# whole self-test mid-run with no indication of which assertion was in flight.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# CA-005: shared --help extractor, sourced rather than hand-copied.
source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"
SELF="$(basename "${BASH_SOURCE[0]:-$0}")"

die() { echo "${SELF}: $*" >&2; exit 2; }

case "${1:-}" in
  -h|--help) print_help "${BASH_SOURCE[0]:-$0}"; exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || die "required binary not found on PATH: jq"

# ---- The promotion rule, expressed once as a jq filter and shared by both real-manifest and
# --self-test runs, so the logic under test is the exact logic that would run for real
# (mirrors bin/edm-compare-eval's one-copy-of-the-threshold discipline). --------------------
_MATRIX_JQ_FILTER='
  .agents[] as $a
  | ($a.baseline.findings // []) as $bf
  | ([$bf[] | select(startswith("P0-") or startswith("P1-"))] | unique) as $bp01
  | ($a.baseline.total_findings) as $btotal
  | (
      [ ($a.results // [] | sort_by(.tier_rank))[]
        | . as $c
        | ($c.findings // []) as $cf
        | ($bp01 - $cf) as $missing
        | (if $btotal > 0 then (($c.total_findings / $btotal * 1000 | round) / 10) else 0 end) as $pct
        | $c + {missing_p0p1: $missing, recall_pct: $pct,
                qualifies: (($missing | length) == 0 and $pct >= 80)}
      ]
    ) as $evaluated
  | ($evaluated | map(select(.qualifies)) | first) as $winner
  | {
      agent: $a.agent,
      baseline_total: $btotal,
      baseline_cost: $a.baseline.cost_usd,
      evaluated: $evaluated,
      winner: $winner
    }
'

# run_matrix <manifest-file> -- prints the table + decision lines for every agent in the
# manifest. Returns 0 always (a "NO CHANGE" decision is a valid outcome, not a script error);
# the caller distinguishes usage/parse errors separately via jq's own exit code.
run_matrix() {
  local manifest="$1"
  local rendered rc=0
  rendered="$(jq -e "$_MATRIX_JQ_FILTER" "$manifest" | jq -s -r '
    .[] | (
      ["=== \(.agent) ===",
       "  baseline: opus/max total_findings=\(.baseline_total) cost_usd=\(.baseline_cost)"]
      + (.evaluated | map(
          "  candidate: \(.model)/\(.effort) tier=\(.tier_rank) total_findings=\(.total_findings) "
          + "recall_pct=\(.recall_pct) missing_p0p1=\(if (.missing_p0p1|length)==0 then "none" else (.missing_p0p1|join(",")) end) "
          + "cost_usd=\(.cost_usd) verdict=\(if .qualifies then "QUALIFIES" else "DISQUALIFIED" end)"
        ))
      + [ (if .winner then
             "DECISION \(.agent): \(.winner.model)/\(.winner.effort) (cheapest qualifying config, tier \(.winner.tier_rank))"
           else
             "DECISION \(.agent): opus/max (no qualifying cheaper config -- unchanged)"
           end),
          "" ]
    ) | .[]
  ')" || rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  [[ -n "$rendered" ]] || die "manifest produced no agent table rows: $manifest"
  printf '%s\n' "$rendered" | grep -q '^DECISION ' || die "manifest produced no DECISION line: $manifest"
  printf '%s\n' "$rendered"
}

# ---- --self-test: three synthetic agents, one per D16 branch --------------------------------
self_test() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/edm-tiering-matrix-selftest.XXXXXX")" || die "mktemp failed"
  trap 'rm -f "$tmp"' RETURN

  cat > "$tmp" <<'EOF'
{
  "agents": [
    {
      "agent": "synthetic-agent-a-qualifies",
      "baseline": {
        "total_findings": 10,
        "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
        "cost_usd": 1.80
      },
      "results": [
        {
          "model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": 9,
          "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "NOTED-1", "NOTED-2"],
          "cost_usd": 0.35
        },
        {
          "model": "opus", "effort": "high", "tier_rank": 2, "total_findings": 10,
          "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
          "cost_usd": 1.05
        }
      ]
    },
    {
      "agent": "synthetic-agent-b-p0-missing",
      "baseline": {
        "total_findings": 10,
        "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
        "cost_usd": 1.80
      },
      "results": [
        {
          "model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": 9,
          "findings": ["P0-1", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
          "cost_usd": 0.35
        },
        {
          "model": "opus", "effort": "high", "tier_rank": 2, "total_findings": 10,
          "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
          "cost_usd": 1.05
        }
      ]
    },
    {
      "agent": "synthetic-agent-c-no-qualifier",
      "baseline": {
        "total_findings": 10,
        "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
        "cost_usd": 1.80
      },
      "results": [
        {
          "model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": 9,
          "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P2-1", "P2-2", "P2-3", "NOTED-1", "NOTED-2"],
          "cost_usd": 0.35
        },
        {
          "model": "opus", "effort": "high", "tier_rank": 2, "total_findings": 7,
          "findings": ["P0-1", "P0-2", "P1-1", "P1-2", "P1-3", "P2-1", "NOTED-1"],
          "cost_usd": 1.05
        }
      ]
    }
  ]
}
EOF

  local out
  out="$(run_matrix "$tmp")" || { echo "self-test: FAIL -- run_matrix errored on the synthetic manifest" >&2; return 1; }

  local failures=0

  # Branch 1: a qualifying cheaper config wins (sonnet/high: 9/10 = 90% total, holds all
  # baseline P0/P1 -- QUALIFIES and wins over the more expensive opus/high).
  if echo "$out" | grep -qxF "DECISION synthetic-agent-a-qualifies: sonnet/high (cheapest qualifying config, tier 1)"; then
    echo "self-test PASS: qualifying cheaper config wins (synthetic-agent-a-qualifies -> sonnet/high)"
  else
    echo "self-test FAIL: expected synthetic-agent-a-qualifies to win sonnet/high" >&2
    failures=$((failures + 1))
  fi

  # Branch 2: sonnet/high is missing baseline finding P0-2 -- disqualified outright regardless
  # of its total-findings ratio -- and the next tier (opus/high, which holds every P0/P1 finding
  # and 100% of total) wins instead.
  if echo "$out" | grep -qxF "DECISION synthetic-agent-b-p0-missing: opus/high (cheapest qualifying config, tier 2)"; then
    echo "self-test PASS: P0-missing config rejected, next tier wins (synthetic-agent-b-p0-missing -> opus/high)"
  else
    echo "self-test FAIL: expected synthetic-agent-b-p0-missing to reject sonnet/high (missing P0-2) and win opus/high" >&2
    failures=$((failures + 1))
  fi
  # Branch 3: sonnet/high is missing baseline finding P1-3 (disqualified); opus/high holds every
  # P0/P1 finding but only 7/10 = 70% of total findings, below the 80% floor (disqualified too).
  # No candidate qualifies -- the agent is left unchanged at opus/max.
  if echo "$out" | grep -qxF "DECISION synthetic-agent-c-no-qualifier: opus/max (no qualifying cheaper config -- unchanged)"; then
    echo "self-test PASS: no qualifying config leaves the agent unchanged (synthetic-agent-c-no-qualifier -> opus/max)"
  else
    echo "self-test FAIL: expected synthetic-agent-c-no-qualifier to stay opus/max (unchanged)" >&2
    failures=$((failures + 1))
  fi

  if echo "$out" | grep -qxF "DECISION synthetic-agent-a-qualifies: sonnet/high (cheapest qualifying config, tier 1)"; then
    :
  else
    failures=$((failures + 1))
  fi

  cat > "$tmp" <<'EOF'
{
  "agents": [
    {
      "agent": "synthetic-agent-d-eighty-qualifies",
      "baseline": {
        "total_findings": 10,
        "findings": ["P0-1", "P1-1", "P1-2", "P2-1", "P2-2", "P2-3", "P2-4", "P2-5", "NOTED-1", "NOTED-2"],
        "cost_usd": 1.80
      },
      "results": [
        {
          "model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": 8,
          "findings": ["P0-1", "P1-1", "P1-2", "P2-1", "P2-9", "P2-10", "NOTED-1", "NOTED-2"],
          "cost_usd": 0.35
        }
      ]
    },
    {
      "agent": "synthetic-agent-e-seventy-nine-disqualified",
      "baseline": {
        "total_findings": 10,
        "findings": ["P0-1", "P1-1", "P1-2", "P2-1", "P2-2", "P2-3", "P2-4", "P2-5", "NOTED-1", "NOTED-2"],
        "cost_usd": 1.80
      },
      "results": [
        {
          "model": "sonnet", "effort": "high", "tier_rank": 1, "total_findings": 7.9,
          "findings": ["P0-1", "P1-1", "P1-2", "P2-1", "P2-9", "P2-10", "NOTED-1", "NOTED-2"],
          "cost_usd": 0.35
        }
      ]
    }
  ]
}
EOF

  out="$(run_matrix "$tmp")" || { echo "self-test: FAIL -- run_matrix errored on the boundary manifest" >&2; return 1; }
  if echo "$out" | grep -qxF "DECISION synthetic-agent-d-eighty-qualifies: sonnet/high (cheapest qualifying config, tier 1)"; then
    echo "self-test PASS: exactly 80 percent qualifies and matching P2 counts need not match IDs"
  else
    echo "self-test FAIL: expected the 80 percent candidate to qualify" >&2
    failures=$((failures + 1))
  fi
  if echo "$out" | grep -qxF "DECISION synthetic-agent-e-seventy-nine-disqualified: opus/max (no qualifying cheaper config -- unchanged)"; then
    echo "self-test PASS: below 80 percent is disqualified"
  else
    echo "self-test FAIL: expected the 79 percent candidate to stay unchanged" >&2
    failures=$((failures + 1))
  fi

  out="$(bash "$0" "$tmp" 2>&1)" || { echo "self-test FAIL: script path invocation errored on a real manifest path" >&2; return 1; }
  if printf '%s\n' "$out" | grep -q '^DECISION '; then
    echo "self-test PASS: real-path invocation prints at least one DECISION line"
  else
    echo "self-test FAIL: real-path invocation produced no DECISION line" >&2
    failures=$((failures + 1))
  fi

  echo
  if [[ "$failures" -eq 0 ]]; then
    echo "self-test: PASS (6/6 promotion-rule assertions verified)"
    return 0
  else
    echo "self-test: FAIL (${failures}/6 assertion(s) failed)" >&2
    return 1
  fi
}

case "${1:-}" in
  "")
    die "usage: ${SELF} <manifest.json> | --self-test | -h|--help"
    ;;
  --self-test)
    self_test
    exit $?
    ;;
  --*)
    die "unknown flag: $1"
    ;;
  *)
    MANIFEST="$1"
    [[ -f "$MANIFEST" ]] || die "manifest file not found: $MANIFEST"
    jq -e . "$MANIFEST" >/dev/null 2>&1 || die "manifest is not valid JSON: $MANIFEST"
    run_matrix "$MANIFEST"
    exit 0
    ;;
esac
