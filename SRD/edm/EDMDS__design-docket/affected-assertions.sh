#!/bin/bash
# affected-assertions.sh -- derive, per EDMDS requirement, every site that depends on the thing that
# requirement changes.
#
# Why this exists (decisions.md D55). Three audit rounds failed on the same class: "a Must
# requirement silently falsifies shipped assertions with no AC owning them". Each round the affected
# set was enumerated by reading, and each round the reading was short -- EDMDS-02 named 2 of 44,
# EDMDS-06 0 of 50, EDMDS-07 7 of 26, EDMDS-16 0 of 47, EDMDS-19 0 of 33.
#
# Why VERSION 2 exists (decisions.md D88). Version 1 replaced a short prose list with a grep that was
# ALSO short, and three independent audit lanes measured it: EDMDS-07 derived 26 against 64 real
# references, EDMDS-10 15 against 106, EDMDS-14's own target derived 0, and EDMDS-19's target was
# blind to the 60 references it needed. Two root causes, both fixed here:
#
#   1. ONE SEARCH ROOT. Every search was `bin/tests/*.sh`, so product code, fixture files under
#      bin/tests/fixtures/, and every documentation surface were structurally invisible. A target
#      now carries its OWN root, and the root is PRINTED beside the count so a reader can see what
#      was not searched. That is the difference between a number and an answer.
#   2. CALL SYNTAX, NOT CALLEE. `audit-round-complete [A-Z0-9]+ code` cannot match
#      `audit-round-complete "$prefix" code` -- which is exactly the ca416_fixture call the SRD
#      credited this script with finding. Targets now anchor on the callee, and a target that must
#      be narrower says so in its label.
#
# The honest limit, stated because version 1's failure was that it did not state one: this finds
# TEXTUAL dependents. An assertion that reaches its subject through a fixture helper is found only
# if a target names something that assertion literally contains. Where that applies, the requirement
# says so and names the helper.
#
# Usage:
#   ./affected-assertions.sh                 # every target: requirement, root, count
#   ./affected-assertions.sh EDMDS-02        # one requirement, every site with file:line
#   ./affected-assertions.sh --check         # exit 2 if a recorded count drifted
#   ./affected-assertions.sh --roots         # what each root name expands to
#
# bash 3.2 floor (CC4): no associative arrays, no mapfile, heredoc-fed `while read` (not pipes) so
# loop variables survive. Fields are TAB-separated -- version 1 used `|`, which silently split a
# pattern containing a grep alternation and reported 0 sites for EDMDS-09, a wrong answer that read
# as a clean one. That is the same class this script exists to catch, found by dogfooding it.

set -uo pipefail   # deliberately no -e: a grep with zero matches is a valid answer (CC3)

PLUGIN_DIR="${EDMDS_PLUGIN_DIR:-$(cd "$(dirname "$0")/../../../plugins/edm" 2>/dev/null && pwd)}"
[[ -d "$PLUGIN_DIR" ]] || { printf 'affected-assertions: no plugin dir at %s\n' "$PLUGIN_DIR" >&2; exit 1; }

# Root names. Each expands to a file list; `files_for_root` is the single place that knows how.
# -H is defensive: POSIX does not guarantee -r implies it, and without it a single-file match
# yields a bare count that awk -F: reads as empty. Checked on this host -- /usr/bin/grep and the
# ugrep shim both force the prefix under -r, and both agree on every recorded count.
files_for_root() {
  case "$1" in
    suites)   printf '%s\n' "$PLUGIN_DIR"/bin/tests/*.sh ;;
    fixtures) find "$PLUGIN_DIR/bin/tests/fixtures" -type f 2>/dev/null ;;
    product)  find "$PLUGIN_DIR/bin" -maxdepth 1 -type f 2>/dev/null ;;
    docs)     { printf '%s\n' "$PLUGIN_DIR/CLAUDE.md" "$PLUGIN_DIR/README.md" "$PLUGIN_DIR/CHANGELOG.md"
                find "$PLUGIN_DIR/agents" "$PLUGIN_DIR/skills" "$PLUGIN_DIR/docs" -type f -name '*.md' 2>/dev/null; } ;;
    hooks)    printf '%s\n' "$PLUGIN_DIR/hooks/hooks.json" ;;
    *)        printf 'affected-assertions: unknown root %s\n' "$1" >&2; return 1 ;;
  esac
}

count_for() {
  local root="$1" pat="$2" n=0 f c
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # grep -c always prints a count, including 0, and returns 1 on no-match. A `|| printf 0`
    # fallback here appended a SECOND zero and broke the arithmetic -- caught by dogfooding.
    c="$(grep -HEc -- "$pat" "$f" 2>/dev/null | awk -F: '{print $NF+0}')"
    n=$(( n + ${c:-0} ))
  done <<EOF
$(files_for_root "$root")
EOF
  printf '%s' "$n"
}

sites_for() {
  local root="$1" pat="$2" f
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    grep -HEn -- "$pat" "$f" 2>/dev/null | sed "s|^${PLUGIN_DIR}/||"
  done <<EOF
$(files_for_root "$root")
EOF
}

# requirement <TAB> root <TAB> label <TAB> grep -E pattern
targets() {
  cat <<'TARGETS'
EDMDS-02	suites	emit_decision, the function restructured	emit_decision
EDMDS-02	suites	stop_gate_emit_blocking, the shape adopted	stop_gate_emit_blocking
EDMDS-02	suites	hookify match-record consumers	hookify_emit_match|eval file
EDMDS-05	suites	the cross-cutting bin/ membership assertions	T50_REQUIRED_BIN_FILES|t50_bin_membership_set
EDMDS-06	suites	inline lens JSONL fixtures	"schema":"lens"
EDMDS-06	fixtures	on-disk lens JSONL fixtures consumed by real completions	"schema"
EDMDS-06	docs	lens prompt schema block (the 14 lenses, not the synthesizer)	JSONL Line Format
EDMDS-07	suites	round completions, anchored on the CALLEE not the call syntax	audit-round-complete
EDMDS-08	suites	suite references to downgrade irreversibility	re-completed|irreversib
EDMDS-09	suites	lenses_na, the set being subtracted	lenses_na
EDMDS-10	product	marker-mutation sites in product code	_edm_marker_write|_edm_marker_remove_if_matches
EDMDS-10	suites	marker assertions	phase-start [A-Z0-9$"{}]+ 6|edm_marker_path
EDMDS-11	suites	CA-500 cross-check and resolver assertions	CA-500|_resolve_permcheck_project_root|edm_project_key
EDMDS-12	suites	active-initiatives consumers and the edm-state shim	active-initiatives|phase=
EDMDS-13	product	the harvested-delta writer	cmd_update_patterns|update-patterns
EDMDS-14	suites	the sanitizer MARKER the assertions key on	LC_ALL=C tr -c
EDMDS-14	product	the sanitizer character set itself	011.012.015.040-.176
EDMDS-14	suites	mutant helpers that stage a consumer	cahk_mutant|w8_mutant_bin|p2g1_mutant_bin
EDMDS-15	suites	the gate-check command body the assertions match on	edm-state gate-check
EDMDS-15	hooks	the five matcher-keyed entries	UserPromptExpansion|gate-check
EDMDS-16	product	the set -e posture under change	set -euo pipefail
EDMDS-16	suites	assertions on consumer error behaviour	CA-077
EDMDS-19	suites	the CA-134 ownership band, via its fixture helper	ca134_resolve|CA134_
EDMDS-19	docs	the bin/ subcommand count and table	subcommands
EDMDS-19	suites	the derived subcommand-count checks	subcommands
EDMDS-20	suites	run/ marker sweep targets	\.phase6|\.checked|\.denials
EDMDS-21	suites	host data-directory isolation (PRECEDENT to copy, not dependents)	CLAUDE_PLUGIN_DATA
R3	suites	the live 200-660 line bound	wc -l < "\$GATEGUARD"
TARGETS
}

# Recorded baseline, measured 2026-09-12. Keyed by requirement and pattern so `--check` can report
# a target that has NO baseline rather than skipping it silently.
baseline_for() {
  local req="$1" root="$2" pat="$3" r rt p n
  while IFS=$'\t' read -r r rt p n; do
    [[ "$r" == "$req" && "$rt" == "$root" && "$p" == "$pat" ]] && { printf '%s' "$n"; return 0; }
  done <<'BASE'
EDMDS-02	suites	emit_decision	44
EDMDS-02	suites	stop_gate_emit_blocking	8
EDMDS-02	suites	hookify_emit_match|eval file	24
EDMDS-05	suites	T50_REQUIRED_BIN_FILES|t50_bin_membership_set	9
EDMDS-06	suites	"schema":"lens"	50
EDMDS-06	fixtures	"schema"	95
EDMDS-06	docs	JSONL Line Format	31
EDMDS-07	suites	audit-round-complete	64
EDMDS-08	suites	re-completed|irreversib	2
EDMDS-09	suites	lenses_na	40
EDMDS-10	product	_edm_marker_write|_edm_marker_remove_if_matches	10
EDMDS-10	suites	phase-start [A-Z0-9$"{}]+ 6|edm_marker_path	51
EDMDS-11	suites	CA-500|_resolve_permcheck_project_root|edm_project_key	37
EDMDS-12	suites	active-initiatives|phase=	15
EDMDS-13	product	cmd_update_patterns|update-patterns	40
EDMDS-14	suites	LC_ALL=C tr -c	4
EDMDS-14	product	011.012.015.040-.176	3
EDMDS-14	suites	cahk_mutant|w8_mutant_bin|p2g1_mutant_bin	38
EDMDS-15	suites	edm-state gate-check	7
EDMDS-15	hooks	UserPromptExpansion|gate-check	11
EDMDS-16	product	set -euo pipefail	22
EDMDS-16	suites	CA-077	15
EDMDS-19	suites	ca134_resolve|CA134_	60
EDMDS-19	docs	subcommands	6
EDMDS-19	suites	subcommands	33
EDMDS-20	suites	\.phase6|\.checked|\.denials	45
EDMDS-21	suites	CLAUDE_PLUGIN_DATA	115
R3	suites	wc -l < "\$GATEGUARD"	1
BASE
  printf ''
}

MODE="${1:-all}"

if [[ "$MODE" == "--roots" ]]; then
  for r in suites fixtures product docs hooks; do
    printf '%-9s %s files\n' "$r" "$(files_for_root "$r" | grep -c . || printf 0)"
  done
  exit 0
fi

if [[ "$MODE" == "--emit-baseline" ]]; then
  # Regenerates the baseline block below from live measurement. The baseline is therefore
  # reproducible rather than hand-typed, which is what stops it drifting from the target list.
  while IFS=$'\t' read -r req root label pat; do
    [[ -n "${req:-}" ]] || continue
    printf '%s\t%s\t%s\t%s\n' "$req" "$root" "$pat" "$(count_for "$root" "$pat")"
  done <<EOF
$(targets)
EOF
  exit 0
fi

if [[ "$MODE" == "--check" ]]; then
  drift=0
  # Baseline lives in one place and is keyed by requirement+pattern, so a target added without a
  # baseline row is REPORTED, never silently invisible -- version 1 kept two parallel hand-maintained
  # lists with nothing enforcing correspondence, which an audit lane flagged as its one structural
  # weakness.
  while IFS=$'\t' read -r req root label pat; do
    [[ -n "${req:-}" ]] || continue
    got="$(count_for "$root" "$pat")"
    want="$(baseline_for "$req" "$root" "$pat")"
    if [[ -z "$want" ]]; then
      printf 'NO BASELINE  %-10s %-9s %s\n' "$req" "$root" "$pat"; drift=1
    elif [[ "$got" != "$want" ]]; then
      printf 'DRIFT        %-10s %-9s %-44s baseline=%s now=%s\n' "$req" "$root" "$(printf '%.44s' "$pat")" "$want" "$got"; drift=1
    fi
  done <<EOF
$(targets)
EOF
  if [[ "$drift" -eq 1 ]]; then
    printf '\nA drift means the affected set moved. Re-read it with ./affected-assertions.sh <REQ>,\n'
    printf 'then update BOTH the requirement and the baseline in the same commit.\n'
    exit 2
  fi
  printf 'affected-assertions: no drift, and every target has a baseline\n'
  exit 0
fi

if [[ "$MODE" == "all" ]]; then
  printf '%-10s  %-9s  %-46s %s\n' "REQ" "ROOT" "TARGET" "SITES"
  printf '%-10s  %-9s  %-46s %s\n' "---" "----" "------" "-----"
  while IFS=$'\t' read -r req root label pat; do
    [[ -n "${req:-}" ]] || continue
    printf '%-10s  %-9s  %-46s %s\n' "$req" "$root" "$(printf '%.46s' "$label")" "$(count_for "$root" "$pat")"
  done <<EOF
$(targets)
EOF
  exit 0
fi

found=0
while IFS=$'\t' read -r req root label pat; do
  [[ "$req" == "$MODE" ]] || continue
  found=1
  printf '\n=== %s [root: %s] -- %s ===\n' "$req" "$root" "$label"
  sites_for "$root" "$pat"
done <<EOF
$(targets)
EOF
[[ "$found" -eq 1 ]] || { printf 'affected-assertions: no targets recorded for %s\n' "$MODE" >&2; exit 1; }
