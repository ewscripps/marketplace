# edm-mermaid-rules.awk -- shared Mermaid fence-recognition and literal-semicolon
# violation-detection rules (CA-019, code-audit round 2).
#
# This file defines ONLY awk functions -- no BEGIN block, no pattern-action rule, no END block --
# so it composes safely as the first of two `-f` arguments to awk:
#
#   awk -f edm-mermaid-rules.awk -f <caller-specific-main-script> <file>
#
# awk concatenates the program text of every `-f` file it is given, in order, into one program.
# Because this file contributes only function *definitions* and no top-level rule of its own, it
# never fires on an input line by itself -- the caller's own main script (the second -f file)
# supplies the BEGIN/per-line/END rules and simply calls the functions below by name. This is the
# reason the extraction was possible without changing either caller's own contract:
# `bin/_edm-lint-lib.sh`'s `build_line_classes` still emits its tab-separated per-line class
# table, and `evals/score-artifacts.sh`'s `_scan_mermaid_blocks` still emits one OK/BAD verdict
# line per fenced block -- only the underlying fence-recognition and semicolon-violation rules
# are now single-sourced between them.
#
# Before this file existed, both callers plus `bin/edm-lint-artifacts`'s own `mermaid_scan_awk`
# helper each carried an independent, byte-equivalent copy of `strip_entities`/`is_violation`
# (round-1 root cause 1, closed a third time here rather than actually shared) -- and
# `evals/score-artifacts.sh`'s fence-open/close detection was anchored at column 1 while
# `bin/_edm-lint-lib.sh`'s was not, so an indented ```mermaid fence (nested under a numbered list
# step or blockquote) was invisible to the scorer's dimension 3 and silently under-counted. All
# three consumers now call the same fence-recognition functions below, so an indented fence is
# recognized identically everywhere.
#
# Functions:
#   mermaid_trim(s)                 -- trim leading/trailing whitespace.
#   mermaid_strip_entities(s)       -- strip legal HTML-style entity codes (#59;, #quot;, #35;,
#                                       any #NNN;) before span-checking, so a legitimate entity
#                                       reference is never mistaken for a raw semicolon.
#   mermaid_is_violation(line)      -- true if `line` contains a literal semicolon inside a
#                                       Mermaid label/edge/message span -- see CLAUDE.md's
#                                       "Mermaid diagram conventions (canonical)" section for the
#                                       rule this implements.
#   mermaid_fence_run_len(line)     -- the number of leading backticks in `line`, counted AFTER
#                                       de-indenting (stripping leading whitespace). 0 if `line`
#                                       has no leading backtick run at all. The de-indent is
#                                       deliberate: real markdown often nests a fenced block under
#                                       a numbered list step or a blockquote, and without
#                                       stripping the leading whitespace before counting
#                                       backticks, an indented fence is invisible to fence
#                                       detection entirely -- see
#                                       bin/tests/fixtures/mermaid/valid/v12-indented-fence.md,
#                                       the regression fixture that exists for exactly this case.
#   mermaid_fence_rest(line)        -- the de-indented remainder of `line` after its leading
#                                       backtick run (the fence "info string", or the trailing
#                                       content on a closing fence line).
#   mermaid_fence_lang(line)        -- the first whitespace-delimited token of a fence-open
#                                       line's info string (e.g. "mermaid"), computed the same
#                                       de-indented way. Empty string if `line` (after
#                                       de-indenting) has fewer than 3 leading backticks.
#   mermaid_is_fence_close(line, fence_len) -- true if `line` closes a fence opened with
#                                       `fence_len` backticks: its own (de-indented) backtick run
#                                       is >= fence_len and nothing but whitespace follows it.

function mermaid_trim(s) {
  sub(/^[[:space:]]*/, "", s)
  sub(/[[:space:]]*$/, "", s)
  return s
}

function mermaid_strip_entities(s,   out, i, n, j, k) {
  out = ""
  i = 1
  n = length(s)
  while (i <= n) {
    if (substr(s, i, 1) == "#") {
      j = i + 1
      k = 0
      while (k < 10 && j <= n && substr(s, j, 1) ~ /[0-9A-Za-z]/) {
        j++
        k++
      }
      if (k >= 1 && j <= n && substr(s, j, 1) == ";") {
        i = j + 1
        continue
      }
    }
    out = out substr(s, i, 1)
    i++
  }
  return out
}

function mermaid_is_violation(line,   trimmed, stripped, after_colon, p) {
  trimmed = mermaid_trim(line)

  # Legal: a Mermaid comment line.
  if (substr(trimmed, 1, 2) == "%%") return 0

  # Legal: classDef / style / linkStyle directives -- their trailing ";" is a statement
  # terminator, never a label boundary.
  # CA-539: merged with the bare-keyword case below rather than keeping it a separate guard --
  # a line whose trimmed form is exactly "classDef"/"style"/"linkStyle" has no ";", no span
  # character and no "->", so it already fell through every check below to return 0 regardless;
  # the separate line was a provably inert no-op. ([[:space:]]|$) covers both shapes in one rule.
  if (trimmed ~ /^(classDef|style|linkStyle)([[:space:]]|$)/) return 0

  stripped = mermaid_strip_entities(line)

  # Legal: a bare statement-terminating ";" at the very end of the line (outside any label) --
  # strip exactly one trailing ";" before span-checking.
  sub(/;[[:space:]]*$/, "", stripped)

  # Label spans: a raw ";" inside [...], (...), {...}, |...|, or "..." is a violation.
  if (stripped ~ /\[[^][]*;[^][]*\]/) return 1
  if (stripped ~ /\([^()]*;[^()]*\)/) return 1
  if (stripped ~ /\{[^{}]*;[^{}]*\}/) return 1
  if (stripped ~ /\|[^|]*;[^|]*\|/) return 1
  if (stripped ~ /"[^"]*;[^"]*"/) return 1

  # Sequence-diagram-style message line: a raw ";" after the first ":" on an arrow line.
  p = index(stripped, ":")
  if (index(stripped, "->") > 0 && p > 0) {
    after_colon = substr(stripped, p + 1)
    if (index(after_colon, ";") > 0) return 1
  }
  return 0
}

function mermaid_fence_run_len(line,   body, n) {
  body = line
  sub(/^[[:space:]]+/, "", body)
  n = 0
  while (substr(body, n + 1, 1) == "`") n++
  return n
}

function mermaid_fence_rest(line,   body, n) {
  body = line
  sub(/^[[:space:]]+/, "", body)
  n = mermaid_fence_run_len(line)
  return substr(body, n + 1)
}

function mermaid_fence_lang(line,   n, rest, info, parts) {
  n = mermaid_fence_run_len(line)
  if (n < 3) return ""
  rest = mermaid_fence_rest(line)
  info = rest
  sub(/^[ \t]+/, "", info)
  split(info, parts, /[ \t]+/)
  return parts[1]
}

function mermaid_is_fence_close(line, fence_len,   n, rest) {
  n = mermaid_fence_run_len(line)
  if (n < fence_len) return 0
  rest = mermaid_fence_rest(line)
  return (rest ~ /^[[:space:]]*$/) ? 1 : 0
}
