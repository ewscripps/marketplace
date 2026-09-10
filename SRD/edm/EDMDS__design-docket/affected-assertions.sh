#!/bin/bash
# affected-assertions.sh -- derive, per EDMDS requirement, every test-suite site that depends on
# the thing that requirement changes.
#
# Why this exists (decisions.md D55). Three audit rounds failed on the same class: "a Must
# requirement silently falsifies shipped assertions with no AC owning them". Each round the
# affected set was enumerated by reading, and each round the reading was short. The v1.1.0 audit
# measured the shortfall: EDMDS-02 named 2 of 44, EDMDS-06 0 of 50, EDMDS-07 7 of 26, EDMDS-16
# 0 of 47, EDMDS-19 0 of 33. Exactly one requirement was complete -- EDMDS-14, 4 of 4 -- and its
# target is a unique string literal. Hand-enumeration is reliable for a unique literal and off by
# three to ten times for a function name, a fixture shape or a config structure.
#
# So the SRD stops carrying lists and carries this instead. Every requirement that touches `bin/`
# names its TARGETS here; the affected set is whatever this prints. The audit re-runs it rather
# than re-reading a list, which is also what makes a drifted set detectable instead of invisible.
#
# Usage:
#   ./affected-assertions.sh                 # every requirement, counts only
#   ./affected-assertions.sh EDMDS-02        # one requirement, every site with file:line
#   ./affected-assertions.sh --check         # exit 2 if any recorded count has drifted
#
# The recorded counts below are a BASELINE, not an expectation: `--check` reports drift so a
# requirement's owner re-reads the new sites. Drift is information, not failure.
#
# bash 3.2 floor (CC4): no associative arrays, no mapfile. Targets are a newline-delimited
# here-doc of `requirement|label|pattern` triples, which bash 3.2 reads with `while read`.

set -uo pipefail   # deliberately no -e: a grep with zero matches is a valid answer (CC3)

PLUGIN_DIR="${EDMDS_PLUGIN_DIR:-$(cd "$(dirname "$0")/../../../plugins/edm" 2>/dev/null && pwd)}"
SUITES="${PLUGIN_DIR}/bin/tests"

[[ -d "$SUITES" ]] || { printf 'affected-assertions: no suite directory at %s\n' "$SUITES" >&2; exit 1; }

# requirement <TAB> human label <TAB> grep -E pattern <TAB> [second pattern]
#
# Fields are TAB-separated, not pipe-separated. The first version of this script used `|`
# and a pattern containing a grep alternation (`lenses \| length`) was silently split,
# reporting 0 sites for EDMDS-09 -- a wrong answer that looked like a clean one, which is
# the exact class this script exists to catch. Caught by dogfooding it on its own output.
#
# A target is what the requirement CHANGES, not what it mentions. `EDMDS-14`'s target is the
# character set itself, because that is the unique literal; `EDMDS-02`'s is the function name,
# because the function's shape is what changes.
targets() {
  cat <<'TARGETS'
EDMDS-02	emit_decision, the function EDMDS-02 restructures	emit_decision
EDMDS-02	stop_gate_emit_blocking, the shape EDMDS-02 adopts	stop_gate_emit_blocking
EDMDS-02	hookify match-record consumers	hookify_emit_match|eval file
EDMDS-06	lens JSONL fixtures that gain a round field	"schema":"lens"
EDMDS-06	lens prompt schema block	JSONL Line Format
EDMDS-07	code-round completions that become partial	audit-round-complete [A-Z0-9]+ code
EDMDS-08	suite assertions on downgrade irreversibility	re-completed|irreversib
EDMDS-09	the lenses array EDMDS-09 shortens	lenses. \| length|lenses_na
EDMDS-10	Phase-6 marker writes	phase-start [A-Z0-9]+ 6
EDMDS-10	marker path helpers the reconciliation touches	edm_marker_path|_edm_marker_(write|remove)
EDMDS-11	unchecked CLAUDE_PROJECT_DIR acceptance	CLAUDE_PROJECT_DIR=
EDMDS-12	active-initiatives and its scrapers	active-initiatives
EDMDS-14	the ASCII sanitizer character set (unique literal)	011.012.015.040-.176
EDMDS-14	mutant harness helpers that stage a consumer	cahk_mutant|w8_mutant_bin|p2g1_mutant_bin
EDMDS-15	UserPromptExpansion matcher-keyed entries	UserPromptExpansion
EDMDS-16	set -euo pipefail, the posture EDMDS-16 changes	set -euo pipefail
EDMDS-19	the bin/ subcommand count and table	subcommands
EDMDS-19	the data-directory ownership test	_edm_datadir_owned|edm_data_dir_claim
EDMDS-20	run/ marker sweep targets	\.phase6|\.checked|\.denials
EDMDS-21	host data-directory isolation	CLAUDE_PLUGIN_DATA
R3	the live 200-660 line bound	wc -l < "\$GATEGUARD"
TARGETS
}

# Recorded baseline: requirement <TAB> pattern <TAB> count, from the run of 2026-09-10.
baseline() {
  cat <<'BASE'
EDMDS-02	emit_decision	44
EDMDS-02	stop_gate_emit_blocking	8
EDMDS-02	hookify_emit_match|eval file	24
EDMDS-06	"schema":"lens"	50
EDMDS-06	JSONL Line Format	17
EDMDS-07	audit-round-complete [A-Z0-9]+ code	26
EDMDS-08	re-completed|irreversib	2
EDMDS-09	lenses. \| length|lenses_na	40
EDMDS-10	phase-start [A-Z0-9]+ 6	15
EDMDS-10	edm_marker_path|_edm_marker_(write|remove)	36
EDMDS-11	CLAUDE_PROJECT_DIR=	124
EDMDS-12	active-initiatives	9
EDMDS-14	011.012.015.040-.176	0
EDMDS-14	cahk_mutant|w8_mutant_bin|p2g1_mutant_bin	38
EDMDS-15	UserPromptExpansion	17
EDMDS-16	set -euo pipefail	47
EDMDS-19	subcommands	33
EDMDS-19	_edm_datadir_owned|edm_data_dir_claim	6
EDMDS-20	\.phase6|\.checked|\.denials	45
EDMDS-21	CLAUDE_PLUGIN_DATA	115
R3	wc -l < "\$GATEGUARD"	1
BASE
}

count_for() { grep -rEc -- "$1" "$SUITES"/*.sh 2>/dev/null | awk -F: '{s+=$2} END{print s+0}'; }
sites_for() { grep -rEn -- "$1" "$SUITES"/*.sh 2>/dev/null | sed "s|^${SUITES}/||"; }

MODE="${1:-all}"

if [[ "$MODE" == "--check" ]]; then
  drift=0
  while IFS=$'\t' read -r req pat want; do
    [[ -n "${req:-}" ]] || continue
    got="$(count_for "$pat")"
    if [[ "$got" != "$want" ]]; then
      printf 'DRIFT  %-10s %-46s baseline=%s now=%s\n' "$req" "$pat" "$want" "$got"
      drift=1
    fi
  done <<EOF
$(baseline)
EOF
  if [[ "$drift" -eq 1 ]]; then
    printf '\nA drifted count means the affected set changed. Re-read the new sites with\n'
    printf './affected-assertions.sh <REQ> and update the requirement before relying on it.\n'
    exit 2
  fi
  printf 'affected-assertions: no drift against the recorded baseline\n'
  exit 0
fi

if [[ "$MODE" == "all" ]]; then
  printf '%-10s  %-46s %s\n' "REQ" "TARGET" "SITES"
  printf '%-10s  %-46s %s\n' "---" "------" "-----"
  while IFS=$'\t' read -r req label pat extra; do
    [[ -n "${req:-}" ]] || continue
    n="$(count_for "$pat")"
    printf '%-10s  %-46s %s\n' "$req" "$(printf '%.46s' "$label")" "$n"
    if [[ -n "${extra:-}" ]]; then
      n2="$(count_for "$extra")"
      printf '%-10s  %-46s %s\n' "" "  (also: $(printf '%.36s' "$extra"))" "$n2"
    fi
  done <<EOF
$(targets)
EOF
  exit 0
fi

# One requirement: every site, with file:line.
found=0
while IFS=$'\t' read -r req label pat extra; do
  [[ "$req" == "$MODE" ]] || continue
  found=1
  printf '\n=== %s -- %s ===\n' "$req" "$label"
  sites_for "$pat"
  if [[ -n "${extra:-}" ]]; then
    printf '\n--- also: %s ---\n' "$extra"
    sites_for "$extra"
  fi
done <<EOF
$(targets)
EOF
[[ "$found" -eq 1 ]] || { printf 'affected-assertions: no targets recorded for %s\n' "$MODE" >&2; exit 1; }
