#!/bin/bash
# control-coverage.sh -- find acceptance criteria that add an assertion without a paired control.
#
# Why this exists. Goal 3 is "add no assertion that cannot fail" and CC1 requires every new assertion
# to carry a negative control. Both are prose constraints, verified by reading -- and reading has
# failed five consecutive revisions: v1.0.0's EDMDS-09 AC2, v1.1.0's EDMDS-10 AC5 and three siblings,
# v1.2.0's EDMDS-19 AC6, v1.3.0's EDMDS-11 AC8, and v1.6.0's EDMDS-20 AC3 / EDMDS-17 AC5 /
# EDMDS-18 AC2. Two audit lanes independently observed the gap: AD-DS6 derives which EXISTING
# assertions an edit disturbs and says nothing about whether a NEW assertion is capable of failing.
#
# This is the Goal 3 analogue of AD-DS6. It cannot decide whether a control is SOUND -- that is an
# audit's job and always will be. It decides whether one was written down at all, which is the cheap
# half, and the half that five rounds of reading kept missing.
#
# Method: an AC is "assertion-bearing" if it promises an assertion or proof. It is "controlled" if
# the same AC, or an AC whose number it names, carries control language. Everything else is reported.
#
# Usage:
#   ./control-coverage.sh            # report uncontrolled assertion-bearing AC
#   ./control-coverage.sh --check    # exit 2 if any are found
#
# Deliberately NOT part of --check's clean bar by default: a handful of AC legitimately assert
# something whose control lives in a sibling requirement, and forcing those to self-describe would
# trade a real signal for noise. The report names them so a reader can judge.

set -uo pipefail   # no -e: a grep with no matches is a valid answer (CC3)

SRD="${1:-srd.md}"
[[ "$SRD" == --* ]] && SRD="srd.md"
[[ -f "$SRD" ]] || { printf 'control-coverage: no SRD at %s\n' "$SRD" >&2; exit 1; }

ASSERTS='an assertion|assertions|asserts|is pinned by an assertion|proven by an assertion|proves'
CONTROLS="control|fails when|fail when|proven (still )?able to fail|can fail|discriminat|negative control|mutant|mutation"

report() {
  local req="" acid="" body="" line n=0
  while IFS= read -r line; do
    case "$line" in
      '#### EDMDS-'*) req="${line#\#\#\#\# }"; req="${req%% *}" ;;
      '- [ ] AC'*)
        [[ -n "$acid" ]] && check_one "$req" "$acid" "$body"
        acid="${line#- \[ \] }"; acid="${acid%%:*}"; body="$line" ;;
      '      '*|'        '*) [[ -n "$acid" ]] && body="$body $line" ;;
      *) [[ -n "$acid" ]] && { check_one "$req" "$acid" "$body"; acid=""; body=""; } ;;
    esac
  done < "$SRD"
  [[ -n "$acid" ]] && check_one "$req" "$acid" "$body"
}

check_one() {
  local req="$1" ac="$2" text="$3"
  printf '%s' "$text" | grep -qE "$ASSERTS" || return 0
  printf '%s' "$text" | grep -iqE "$CONTROLS" && return 0
  # The document's convention is "ACn: an assertion ..." followed by "ACn+1: ACn's control -- ...".
  # So an AC is controlled if the NEXT AC in the same requirement carries control language AND names
  # it, or carries control language and names no other AC (a bare "AC5's control" form). Checking
  # only ACs the text itself names produced 19 findings of which most were this pattern -- a checker
  # that noisy is as useless as one that misses, so the adjacency rule is the load-bearing half.
  local nxt
  nxt="$(awk -v r="$req" -v a="$ac" '
    $0 ~ "^#### " r " " {inreq=1; next}
    /^#### EDMDS-/ {inreq=0}
    inreq && $0 ~ "^- \\[ \\] " a ":" {seen=1; next}
    seen && /^- \[ \] AC/ {grab=1}
    grab {print; if (/^- \[ \] AC/ && ++n>1) exit}
  ' "$SRD")"
  if printf '%s' "$nxt" | grep -iqE "$CONTROLS"; then
    printf '%s' "$nxt" | grep -qE "\b${ac}\b" && return 0
    printf '%s' "$nxt" | grep -qE "^- \[ \] AC[0-9]+[a-z]?: (AC[0-9]+[a-z]?'s )?control" && return 0
  fi
  # Broadest correct rule: ANY AC in this requirement whose text carries control language AND names
  # this AC. EDMDS-01 AC2's control is AC6, four criteria later -- adjacency alone misses it, and a
  # control that far from its assertion is still a control.
  awk -v r="$req" '
    $0 ~ "^#### " r " " {inreq=1; next}
    /^#### EDMDS-/ {inreq=0}
    inreq {print}
  ' "$SRD" | grep -iE "$CONTROLS" | grep -qE "\b${ac}\b" && return 0
  # A control may also live in a sibling AC that this one names.
  local sib
  for sib in $(printf '%s' "$text" | grep -oE 'AC[0-9]+[a-z]?'); do
    [[ "$sib" == "$ac" ]] && continue
    awk -v r="$req" -v a="$sib" '
      $0 ~ "^#### " r " " {inreq=1; next}
      /^#### EDMDS-/ {inreq=0}
      inreq && $0 ~ "^- \\[ \\] " a ":" {found=1}
      found && /^- \[ \] AC/ && $0 !~ "^- \\[ \\] " a ":" {exit}
      found {print}
    ' "$SRD" | grep -iqE "$CONTROLS" && return 0
  done
  printf '%-11s %-6s %s\n' "$req" "$ac" "$(printf '%s' "$text" | sed 's/^- \[ \] AC[0-9]*[a-z]*: //' | cut -c1-84)"
  return 1
}

OUT="$(report)"
if [[ -z "$OUT" ]]; then
  printf 'control-coverage: every assertion-bearing AC names a control\n'
  exit 0
fi
printf 'Assertion-bearing acceptance criteria with no control named here or in a sibling AC:\n\n'
printf '%-11s %-6s %s\n' "REQ" "AC" "WHAT IT ASSERTS"
printf '%-11s %-6s %s\n' "---" "--" "---------------"
printf '%s\n' "$OUT"
printf '\n%s findings. Goal 3: "add no assertion that cannot fail"; CC1 requires the control.\n' "$(printf '%s\n' "$OUT" | grep -c .)"
[[ "${1:-}" == "--check" ]] && exit 2
exit 0
