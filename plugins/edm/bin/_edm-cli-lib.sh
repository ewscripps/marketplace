#!/usr/bin/env bash
# _edm-cli-lib.sh -- shared --help extractor for every bin/ helper and evals/ driver (CA-005).
# Never executed directly; always sourced.
#
# Why this file exists: before CA-005, the same one-line sentinel extractor was hand-copied
# twelve times across bin/ and evals/ in three incompatible shapes -- most kept the leading
# "# " on each printed line, a minority stripped it, and edm-sync-canonical-sections skipped
# sentinels entirely and keyed its extraction on the literal `set -euo pipefail` line instead
# (fragile -- moving that line silently truncated its --help). This file is the only place
# outside bin/tests/ the extractor awk literal may appear -- bin/tests/ is exempted because the
# smoke suite must carry the literal in order to assert on it; every bin/ helper and evals/
# driver sources this file and calls print_help instead of hand-copying it. lint:bash-syntax
# (.gitlab-ci.yml) greps for and bans a second occurrence of the literal outside bin/tests/, and
# separately bans the hardcoded `sed -n 'A,Bp' "$0"` line-range form this replaces.
#
# print_help <script-path>
#   Prints everything between the EDM-HELP-BEGIN/EDM-HELP-END sentinel comment lines near the
#   top of <script-path>, verbatim. The leading "# " on each printed line is KEPT -- the settled
#   convention (eight of the twelve pre-existing copies already rendered it this way; this file
#   keeps that majority form rather than introducing a fourth shape). awk, never a hardcoded
#   line-range `sed -n`: a hardcoded range silently stops covering a doc line added below its
#   end unless two numbers are bumped in lockstep, which is exactly the bug this sentinel form
#   fixes.
#
# Callers pass their own path explicitly (`print_help "${BASH_SOURCE[0]:-$0}"`) rather than this
# function reading $0/BASH_SOURCE itself: BASH_SOURCE[0] inside a function defined in a sourced
# library resolves to THIS file's own path, not the caller's, so this function cannot safely
# guess which script's sentinel block to extract.
print_help() {
  awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f' "$1"
}
