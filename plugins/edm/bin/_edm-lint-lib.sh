#!/usr/bin/env bash

build_line_classes() {
  local file="$1"
  awk '
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

      if (ignore_next == 1) {
        print lineno "\tignored"
        print lineno "\tmarker"
        ignore_next = 0
        next
      }

      fence_body = line
      sub(/^[[:space:]]+/, "", fence_body)
      run_len = 0
      while (substr(fence_body, run_len + 1, 1) == "`") run_len++
      rest = substr(fence_body, run_len + 1)

      if (in_fence == 0 && run_len >= 3) {
        info = rest
        sub(/^[ \t]+/, "", info)
        split(info, parts, /[ \t]+/)
        lang = parts[1]
        in_fence = 1
        fence_len = run_len
        fence_open_line = lineno
        if (lang == "mermaid") {
          in_mermaid = 1
          mermaid_suppressed = (index(line, "<!-- edm-lint-ignore -->") > 0) ? 1 : 0
        } else {
          in_mermaid = 0
          mermaid_suppressed = 0
        }
        next
      }

      if (in_fence == 1 && run_len >= fence_len && rest ~ /^[[:space:]]*$/) {
        in_fence = 0
        fence_len = 0
        fence_open_line = 0
        in_mermaid = 0
        mermaid_suppressed = 0
        next
      }

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
  ' "$file"
}

is_ignored_line() {
  local lineno="$1" lineset="$2"
  [[ -n "$lineset" ]] && echo "$lineset" | grep -qxF "$lineno"
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
  elif [[ -n "${VIOLATIONS+x}" ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
}
