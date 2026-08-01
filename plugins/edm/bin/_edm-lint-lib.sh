#!/usr/bin/env bash
# _edm-lint-lib.sh -- shared line-classification and violation-reporting helpers.
#
# This file is meant to be `source`d, never executed directly. Its three consumers are
# bin/edm-lint-artifacts, bin/edm-check-grants and bin/edm-check-vocabulary. All three source it
# by relative path from their own script directory (`source "${SELF_DIR}/_edm-lint-lib.sh"` or
# equivalent) so it works regardless of the caller's PATH or cwd.
#
# Functions:
#   build_line_classes <file>
#     Emits one tab-separated record per line PER CLASS that applies to it (a line can appear
#     zero, one, or two times -- e.g. a line inside an ignore block is both "ignored" and
#     "marker"). Four classes:
#       <lineno>\tignored              -- inside a fenced code block OR an
#                                          edm-lint-ignore-start/-end block; most violation
#                                          classes skip these lines entirely.
#       <lineno>\tmarker               -- the line itself is (or is covered by) an
#                                          edm-lint-ignore / -start / -end marker; used to
#                                          distinguish "an ignore marker exists here" from
#                                          "content is merely suppressed" (e.g. class 4's
#                                          misused-marker-inside-a-mermaid-fence detection).
#       <lineno>\tmermaid              -- inside a fenced ```mermaid block (and not itself
#                                          suppressed by a single-line edm-lint-ignore on the
#                                          fence-open line).
#       <lineno>\tunterminated-fence\t<snippet> -- emitted once, at END, for a fence that is
#                                          still open at EOF; <lineno> is the fence-open line.
#     Fence-open/close detection de-indents each line (strips leading whitespace) before
#     counting backtick runs -- see the comment on the shared `mermaid_fence_run_len` call below
#     for why (an indented fence, e.g. one nested under a numbered list step, must still be
#     recognized). Fence and ignore-marker detection is delegated to
#     bin/edm-mermaid-rules.awk (CA-019) so this file, bin/edm-lint-artifacts's own Mermaid scan,
#     and evals/score-artifacts.sh's standalone scanner all agree on what counts as a fence.
#
#   is_ignored_line <lineno> <lineset>
#     True if <lineno> appears (as a whole line) in the newline-separated <lineset> string --
#     typically one of the sets below, or a caller-derived filter of build_line_classes' output.
#
#   ignored_line_set <file> / mermaid_line_set <file> / marker_line_set <file>
#     Convenience projections of build_line_classes onto one class each, returning a
#     newline-separated set of line numbers. These exist so all three consumers derive the
#     "ignored"/"mermaid"/"marker" sets identically instead of each re-deriving the same
#     `build_line_classes "$file" | awk -F'\t' '$2=="..."{print $1}'` projection locally
#     (CA-156) -- callers wanting more than one set from the same file may still call
#     build_line_classes directly to avoid re-scanning the file per projection (as
#     bin/edm-lint-artifacts does).
#
#   report_violation <class> <file> <lineno> <snippet>              -- 4-arg form.
#     Prints "<file>:<lineno>: <class>: <snippet>" (path:line: class: snippet). Used by
#     bin/edm-lint-artifacts and bin/edm-check-vocabulary, e.g.:
#       report_violation "unicode" "srd.md" "42" "some non-ascii text"
#       -> "srd.md:42: unicode: some non-ascii text"
#
#   report_violation <kind> <name> <class> <file> <lineno>           -- 5-arg form.
#     Prints "<kind>: <name>: <class>: <file>:<lineno>" -- note the field ORDER differs from the
#     4-arg form, not just the arity: <file> and <lineno> move to the end, joined by ":" instead
#     of leading the line. Used by bin/edm-check-grants, e.g.:
#       report_violation "agent" "edm-audit-runtime" "missing-write-grant" "agents/x.md" "12"
#       -> "agent: edm-audit-runtime: missing-write-grant: agents/x.md:12"
#
#   Counter convention: every caller of report_violation MUST declare an integer variable named
#   `violations` (lowercase, initialized e.g. `violations=0`) in its own scope BEFORE the first
#   call. report_violation increments it by one per call. A caller that has not declared
#   `violations` gets a hard failure (report_violation returns 1) rather than a silently
#   uncounted violation -- see CA-155: an earlier version of this function guessed between two
#   caller-side counter spellings (`violations` and `VIOLATIONS`), which encoded the two existing
#   callers' naming divergence instead of resolving it, and meant a violation could be printed
#   but never counted, letting a dirty tree exit 0.

SELF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERMAID_RULES_AWK="${SELF_LIB_DIR}/edm-mermaid-rules.awk"

build_line_classes() {
  local file="$1"
  awk -f "$MERMAID_RULES_AWK" -f <(cat <<'AWK_MAIN'
    function apply_fence_open(line, lineno,    lang) {
      in_fence = 1
      fence_len = mermaid_fence_run_len(line)
      fence_open_line = lineno
      lang = mermaid_fence_lang(line)
      if (lang == "mermaid") {
        in_mermaid = 1
        mermaid_suppressed = (index(line, "<!-- edm-lint-ignore -->") > 0) ? 1 : 0
      } else {
        in_mermaid = 0
        mermaid_suppressed = 0
      }
    }
    function apply_fence_close() {
      in_fence = 0
      fence_len = 0
      fence_open_line = 0
      in_mermaid = 0
      mermaid_suppressed = 0
    }
    BEGIN {
      in_fence=0
      fence_len=0
      fence_open_line=0
      in_ignore_block=0
      ignore_next=0
      in_mermaid=0
      mermaid_suppressed=0
    }
    {
      line = $0
      sub(/\r$/, "", line)
      lineno = NR

      # CA-144: fence-open/close detection is computed here, UNCONDITIONALLY, before the
      # ignore_next short-circuit below is allowed to next the current line away. The previous
      # ordering let an edm-lint-ignore marker on the line directly before a fence opener consume
      # the opener itself via that next -- in_fence never became 1, so the fence's own CLOSING
      # line was then matched by the (still-armed) opener branch instead, inverting
      # fence-suppression state for the rest of the file. NOTE: this comment intentionally avoids
      # backtick characters -- bash 3.2 mis-parses a backtick inside a quoted heredoc that is
      # itself nested inside a <(...) process substitution (confirmed empirically), so no
      # backtick may appear anywhere in this second -f script below.
      is_open = (in_fence == 0 && mermaid_fence_run_len(line) >= 3) ? 1 : 0
      is_close = (in_fence == 1 && mermaid_is_fence_close(line, fence_len)) ? 1 : 0

      if (ignore_next == 1) {
        print lineno "\tignored"
        print lineno "\tmarker"
        ignore_next = 0
        # The fence's own open/close bookkeeping still applies even though this line was also
        # ignore-marked -- an ignore marker suppresses CONTENT, it does not un-open or un-close
        # a fence.
        if (is_open) apply_fence_open(line, lineno)
        else if (is_close) apply_fence_close()
        next
      }

      if (is_open) { apply_fence_open(line, lineno); next }
      if (is_close) { apply_fence_close(); next }

      if (index(line, "<!-- edm-lint-ignore-end -->") > 0) {
        in_ignore_block = 0
        next
      }

      if (in_fence == 1 || in_ignore_block == 1) print lineno "\tignored"
      if (in_ignore_block == 1) print lineno "\tmarker"
      if (in_mermaid == 1 && mermaid_suppressed == 0) print lineno "\tmermaid"

      if (index(line, "<!-- edm-lint-ignore-start -->") > 0) in_ignore_block = 1
      if (index(line, "<!-- edm-lint-ignore -->") > 0 && in_mermaid == 0) ignore_next = 1
    }
    END {
      if (in_fence == 1) {
        print fence_open_line "\tunterminated-fence\tfence opened here is never closed"
      }
    }
AWK_MAIN
  ) "$file"
}

is_ignored_line() {
  local lineno="$1" lineset="$2"
  [[ -n "$lineset" ]] && echo "$lineset" | grep -qxF "$lineno"
}

# ignored_line_set / mermaid_line_set / marker_line_set <file> -- single-sourced projections of
# build_line_classes onto one class each (CA-156). Each re-scans the file via build_line_classes;
# a caller that needs more than one of these sets for the same file should call
# build_line_classes once itself and derive all needed projections from that one table instead
# (bin/edm-lint-artifacts does this).
ignored_line_set() {
  local file="$1"
  build_line_classes "$file" | awk -F'\t' '$2=="ignored"{print $1}'
}

mermaid_line_set() {
  local file="$1"
  build_line_classes "$file" | awk -F'\t' '$2=="mermaid"{print $1}'
}

marker_line_set() {
  local file="$1"
  build_line_classes "$file" | awk -F'\t' '$2=="marker"{print $1}'
}

report_violation() {
  if [[ $# -eq 4 ]]; then
    printf '%s:%s: %s: %s\n' "$2" "$3" "$1" "$4"
  elif [[ $# -eq 5 ]]; then
    printf '%s: %s: %s: %s:%s\n' "$1" "$2" "$3" "$4" "$5"
  else
    echo "_edm-lint-lib.sh: report_violation expected 4 or 5 args, got $#" >&2
    return 1
  fi

  if [[ -n "${violations+x}" ]]; then
    violations=$((violations + 1))
  else
    echo "_edm-lint-lib.sh: report_violation: caller has not declared a 'violations' counter -- refusing to silently undercount" >&2
    return 1
  fi
}
