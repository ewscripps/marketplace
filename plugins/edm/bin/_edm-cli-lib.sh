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

# sanitize_ascii <text> -- print <text> with every byte outside tab/CR/LF and the printable ASCII
# range 0x20-0x7E replaced with '?' (never dropped, so line count and fact-list structure survive
# unchanged). EDMDS-14 (CA-072): this was hand-copied three times -- edm-gateguard's
# emit_decision (a denial reason built from a repository path or a matched hookify rule's own
# message), edm-hookify's hookify_scrub (matched-rule fields: name/action/message, plus setup-
# error path text), and edm-stop-gate's stop_gate_emit_blocking (a validate anomaly line or a
# matched stop-event rule's message) -- all three interpolate text this plugin does not control
# (a rule author, a repository path) into a model-facing or JSON-bound channel (EDMV4-T52 AC6/
# AC7). One owner now; every consumer calls this instead of re-typing the `tr` invocation, so a
# future fourth copy (the exact defect that put a copy at edm-bash-gate's only sanitizer-less
# emit site, closed by this same requirement's AC6) cannot happen by construction.
#
# Deliberately NOT guarded the way this file's sibling `_edm-datadir-lib.sh` is (source wrapped in
# `[[ -r ... ]]` at every consumer, degrading a missing file to "no gate at all"): a missing
# datadir lib disables an optional marker/gate feature, which is an acceptable degradation, but a
# missing sanitizer would mean untrusted text reaches a model-facing or JSON control channel with
# no filter at all -- a strictly worse failure mode than refusing to run. Every consumer therefore
# sources this file with an explicit `|| { ...; exit 1; }` guard instead (EDMDS-14 AC2).
sanitize_ascii() {
  printf '%s' "$1" | LC_ALL=C tr -c '\011\012\015\040-\176' '?'
}
