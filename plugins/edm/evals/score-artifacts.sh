#!/usr/bin/env bash
# score-artifacts.sh -- deterministic mechanical scorer for EDM eval runs (EDMV3-T23,
# SRD EDMV3-27, EDMV3-28, EDMV3-29). Turns a run directory (as produced by run-eval.sh,
# EDMV3-T22) into a scores.json with exactly five dimensions. No model is in the loop:
# every dimension is computed by grep/awk/jq over the run's own artifact files, so the
# same run directory scores the same way every time (AC6).
#
# Usage:
#   score-artifacts.sh <run-dir>              Score one run directory. Writes
#                                              <run-dir>/scores.json and prints the same
#                                              JSON to stdout. Exit 0 whenever a score was
#                                              produced -- a terrible score is still exit 0
#                                              (AC5). Exit 2 on a usage or environment
#                                              error (missing jq, missing run-dir, missing
#                                              vague-ac-patterns.txt).
#   score-artifacts.sh --describe             Print the five dimension definitions
#                                              verbatim and exit 0.
#   score-artifacts.sh --compare <a> <b>       Compare two scores.json files. Refuses
#                                              (exit 1) when scorer_version or
#                                              dimensions_scored differ between them,
#                                              naming the mismatch. This is the only
#                                              comparison logic in this file -- the
#                                              default scoring mode above never compares
#                                              against anything and never exits non-zero
#                                              on a low score (AC5). The actual pass/fail
#                                              CI decision that consumes --compare's output
#                                              is EDMV3-T39's job (srd.md EDMV3-52), not
#                                              this ticket's.
#   score-artifacts.sh -h|--help               Show this help.
#
# The five dimensions, in fixed order (AC1, exactly five -- never "at least five"):
#   1. requirement-id-coverage        -- every {PREFIX}-NN ID in the SRD is unique,
#                                         sequential with no gaps, and appears in the
#                                         audit report's coverage discussion.
#   2. ac-testability                 -- ACs matching vague-ac-patterns.txt divided by
#                                         total AC count, inverted so higher is better.
#   3. mermaid-parse-success          -- every ```mermaid``` block parses and contains no
#                                         raw ; in label text (EDMV3-56 detection rule).
#   4. coverage-map-bidirectionality  -- coverage-map bidirectionality where the run
#                                         reached the ticket phase, falling back to
#                                         srd.md <-> audit-srd.md ID bidirectionality when
#                                         it did not (every wave-A eval run today).
#   5. lens-jsonl-prose-agreement     -- per-lens finding counts, lens-L{N}.md versus
#                                         lens-L{N}.jsonl, for a run including a code-audit
#                                         round.
#
# Each dimension normalizes to an integer 0-100, higher is better (dimension 2 is inverted
# at normalization time: 100 * (1 - vague/total)). A dimension that cannot be computed is
# emitted with score: null, named in dimensions_skipped with a one-line reason, and
# excluded from both the sum and the denominator. total is the unweighted arithmetic mean
# of the dimensions that produced a number, divided by dimensions_scored (read from the
# data, never assumed to be 5), rounded to one decimal place:
#
#   jq -e '. as $r | ([$r.dimensions[].score | select(. != null)] | add) as $sum
#          | $r.dimensions_scored as $n | (($sum / $n * 10 | round) / 10) == $r.total' \
#     <run-dir>/scores.json
#
# This is the exact expression score-artifacts.sh's own output satisfies -- there is no
# licence to adapt it (EDMV3-T23 AC3). jq's floating-point rounding is not reliable across
# every build, so the mean is computed here in integer tenths (awk) and formatted to one
# decimal place only at print time (EDMV3-T23 Technical Notes).
#
# Dimension 3's "no raw ; in label text" check is score-artifacts.sh's own standalone
# Mermaid-block scan, not a call into bin/edm-lint-artifacts: as of this ticket landing,
# edm-lint-artifacts has three violation classes (attribution, unicode, leaked-tool-tag)
# and does not yet have the fourth Mermaid-semicolon class described by EDMV3-56 (wave B).
# When that class lands, dimension 3 should be updated to consume it directly (via
# `edm-lint-artifacts --path <run-dir>`) rather than maintain a second implementation of
# the same rule (EDMV3-111) -- there is nothing to consume yet, so that is a follow-up,
# not a defect in this ticket.
#
# Depends on nothing beyond bash 3.2 and jq (AC6). Never calls bin/edm-state, never reads
# ANTHROPIC_API_KEY, never launches claude -- this script only ever reads files under the
# run directory it is given.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER_VERSION="1.0.0"
PATTERNS_FILE="$SCRIPT_DIR/vague-ac-patterns.txt"

DIM_NAMES=(requirement-id-coverage ac-testability mermaid-parse-success coverage-map-bidirectionality lens-jsonl-prose-agreement)

die() {
  echo "score-artifacts: $*" >&2
  exit 2
}

usage() {
  sed -n '2,45p' "${BASH_SOURCE[0]}"
}

describe() {
  cat <<'EOF'
Dimension 1 (requirement-id-coverage): checks that every {PREFIX}-NN ID in the SRD is
unique, sequential with no gaps, and appears in the audit report's coverage discussion.

Dimension 2 (ac-testability): counts ACs matching the vague-AC regexes divided by total
AC count.

Dimension 3 (mermaid-parse-success): checks every ```mermaid``` block parses and contains
no raw ; in label text per the EDMV3-56 detection rule.

Dimension 4 (coverage-map-bidirectionality): checks coverage-map bidirectionality where
the run reached the ticket phase.

Dimension 5 (lens-jsonl-prose-agreement): compares per-lens finding counts between
lens-L{N}.md and lens-L{N}.jsonl for a run including a code-audit round.
EOF
}

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# ---- shared numeric helpers --------------------------------------------------------------

# round_int <float> -- nearest integer, half away from zero.
round_int() {
  awk -v v="$1" 'BEGIN{ if (v<0) printf "%d", int(v-0.5); else printf "%d", int(v+0.5) }'
}

# score_from_ratio <numerator> <denominator> -- 100*num/den, rounded, clamped to 0-100.
# denominator <= 0 yields 0 (caller decides whether that should instead be a null/skip).
score_from_ratio() {
  local num="$1" den="$2"
  awk -v n="$num" -v d="$den" '
    BEGIN {
      if (d <= 0) { printf "%d", 0; exit }
      v = 100 * n / d
      if (v < 0) v = 0
      if (v > 100) v = 100
      r = (v < 0) ? int(v - 0.5) : int(v + 0.5)
      printf "%d", r
    }'
}

# ---- dimension 1: requirement-id-coverage ------------------------------------------------
compute_dim1() {
  local run_dir="$1"
  local srd="$run_dir/srd.md"
  if [[ ! -f "$srd" ]]; then
    D1_SCORE=""; D1_REASON="no srd.md in run directory"; return
  fi

  local ids
  ids="$(grep -oE '^#### [A-Za-z][A-Za-z0-9]*-[0-9]+' "$srd" 2>/dev/null | sed -E 's/^#### //')"
  if [[ -z "$ids" ]]; then
    D1_SCORE=""; D1_REASON="no {PREFIX}-NN requirement headings found in srd.md"; return
  fi

  local total_ids unique_ids unique_count
  total_ids=$(printf '%s\n' "$ids" | grep -c .)
  unique_ids="$(printf '%s\n' "$ids" | sort -u)"
  unique_count=$(printf '%s\n' "$unique_ids" | grep -c .)
  local uniqueness_score
  uniqueness_score=$(score_from_ratio "$unique_count" "$total_ids")

  # Sequential-with-no-gaps: numeric suffixes across all unique IDs (regardless of the
  # textual prefix, which is expected to be constant for one initiative's srd.md).
  local nums present_count max_num sequence_score
  nums="$(printf '%s\n' "$unique_ids" | sed -E 's/^.*-0*([0-9]+)$/\1/' | sort -n -u)"
  present_count=$(printf '%s\n' "$nums" | grep -c .)
  max_num=$(printf '%s\n' "$nums" | tail -1)
  [[ -z "$max_num" || "$max_num" -le 0 ]] && max_num=1
  sequence_score=$(score_from_ratio "$present_count" "$max_num")

  # Coverage: each unique ID appears somewhere in audit-srd.md's discussion.
  local audit="$run_dir/audit-srd.md"
  local coverage_score found=0 id
  if [[ -f "$audit" ]]; then
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      grep -qF -- "$id" "$audit" && found=$((found + 1))
    done <<< "$unique_ids"
    coverage_score=$(score_from_ratio "$found" "$unique_count")
  else
    coverage_score=0
  fi

  local avg
  avg=$(awk -v a="$uniqueness_score" -v b="$sequence_score" -v c="$coverage_score" \
    'BEGIN{printf "%.4f", (a + b + c) / 3}')
  D1_SCORE="$(round_int "$avg")"
  D1_REASON=""
}

# ---- dimension 2: ac-testability ---------------------------------------------------------
compute_dim2() {
  local run_dir="$1"
  local srd="$run_dir/srd.md"
  if [[ ! -f "$srd" ]]; then
    D2_SCORE=""; D2_REASON="no srd.md in run directory"; return
  fi

  # Join each AC bullet with its indented continuation lines into one logical line, so a
  # vague word appearing only on a wrapped continuation (common in real srd.md ACs) is
  # still matched.
  local ac_lines
  ac_lines="$(awk '
    function flush() { if (buf != "") { print buf; buf="" } }
    /^[[:space:]]*-[[:space:]]*\[[ xX]\]/ { flush(); buf=$0; next }
    buf != "" && /^[[:space:]]+[^[:space:]]/ { buf = buf " " $0; next }
    { flush() }
    END { flush() }
  ' "$srd")"

  local total_ac
  total_ac=$(printf '%s\n' "$ac_lines" | grep -c . || true)
  if [[ "$total_ac" -eq 0 ]]; then
    D2_SCORE=""; D2_REASON="no Acceptance Criteria bullets found in srd.md"; return
  fi

  [[ -s "$PATTERNS_FILE" ]] || die "vague-ac-patterns.txt not found or empty at $PATTERNS_FILE"
  local active_patterns
  active_patterns="$(grep -vE '^[[:space:]]*(#|$)' "$PATTERNS_FILE")"

  local vague_count
  vague_count=$(printf '%s\n' "$ac_lines" | grep -icE -f <(printf '%s\n' "$active_patterns") || true)
  [[ -z "$vague_count" ]] && vague_count=0

  D2_SCORE="$(score_from_ratio "$((total_ac - vague_count))" "$total_ac")"
  D2_REASON=""
}

# ---- dimension 3: mermaid-parse-success --------------------------------------------------

# _scan_mermaid_blocks <file> -- prints one "OK" or "BAD" line per fenced ```mermaid block
# found in <file>. A block is OK when: it has a closing fence (not still open at EOF), its
# first non-blank content line begins with a recognized Mermaid diagram-type keyword, and
# no line in the block contains a raw semicolon inside a label context ([...], "...",
# (...), or a |...| edge label) once known HTML entity escapes (#59;, #35;, #quot;, and any
# #NNN; numeric entity) have been stripped first.
_scan_mermaid_blocks() {
  local file="$1"
  awk '
    BEGIN { in_block=0; first_line=1; bad=0; has_content=0 }
    /^```[Mm][Ee][Rr][Mm][Aa][Ii][Dd][[:space:]]*$/ {
      if (in_block) next
      in_block=1; first_line=1; bad=0; has_content=0
      next
    }
    in_block && /^```[[:space:]]*$/ {
      if (has_content == 0) bad = 1
      print (bad == 0 ? "OK" : "BAD")
      in_block = 0
      next
    }
    in_block {
      line = $0
      if (line ~ /^[[:space:]]*$/) next
      has_content = 1
      if (first_line) {
        first_line = 0
        stripped = line
        gsub(/^[[:space:]]+/, "", stripped)
        if (stripped !~ /^(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram|gantt|pie|journey|gitGraph|mindmap|timeline|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment)/) {
          bad = 1
        }
      }
      stripped_line = line
      gsub(/#(59|35|quot|[0-9]+);/, "", stripped_line)
      if (stripped_line ~ /\[[^]]*;[^]]*\]/) bad = 1
      if (stripped_line ~ /"[^"]*;[^"]*"/) bad = 1
      if (stripped_line ~ /\([^)]*;[^)]*\)/) bad = 1
      if (stripped_line ~ /\|[^|]*;[^|]*\|/) bad = 1
      next
    }
    END { if (in_block) print "BAD" }
  ' "$file"
}

compute_dim3() {
  local run_dir="$1"
  local candidate files=() f
  for candidate in planning.md srd.md architecture.md audit-srd.md; do
    [[ -f "$run_dir/$candidate" ]] && files+=("$run_dir/$candidate")
  done
  if [[ ${#files[@]} -eq 0 ]]; then
    D3_SCORE=""; D3_REASON="no run artifacts found to scan for mermaid blocks"; return
  fi

  local total_blocks=0 good_blocks=0 verdict
  for f in "${files[@]}"; do
    while IFS= read -r verdict; do
      [[ -z "$verdict" ]] && continue
      total_blocks=$((total_blocks + 1))
      [[ "$verdict" == "OK" ]] && good_blocks=$((good_blocks + 1))
    done < <(_scan_mermaid_blocks "$f")
  done

  if [[ "$total_blocks" -eq 0 ]]; then
    D3_SCORE=""; D3_REASON="no mermaid blocks found in run artifacts"; return
  fi
  D3_SCORE="$(score_from_ratio "$good_blocks" "$total_blocks")"
  D3_REASON=""
}

# ---- dimension 4: coverage-map-bidirectionality ------------------------------------------
compute_dim4() {
  local run_dir="$1"
  local srd="$run_dir/srd.md"
  if [[ ! -f "$srd" ]]; then
    D4_SCORE=""; D4_REASON="no srd.md in run directory"; return
  fi

  local prefix
  prefix="$(grep -oE '^#### [A-Za-z][A-Za-z0-9]*-[0-9]+' "$srd" 2>/dev/null | head -1 | sed -E 's/^#### //; s/-[0-9]+$//')"
  if [[ -z "$prefix" ]]; then
    D4_SCORE=""; D4_REASON="could not determine a requirement-ID prefix from srd.md"; return
  fi

  local srd_ids srd_count
  srd_ids="$(grep -oE "^#### ${prefix}-[0-9]+" "$srd" 2>/dev/null | sed -E 's/^#### //' | sort -u)"
  srd_count=$(printf '%s\n' "$srd_ids" | grep -c . || true)
  if [[ "$srd_count" -eq 0 ]]; then
    D4_SCORE=""; D4_REASON="no ${prefix}-NN requirement IDs found in srd.md"; return
  fi

  # Primary source: the ticket phase's own coverage map, when the run reached it.
  # Fallback source (every wave-A eval run, which never reaches the ticket phase):
  # srd.md <-> audit-srd.md ID bidirectionality -- every declared ID must appear in the
  # audit, and every ID-shaped token the audit references must actually exist in srd.md
  # (no fabricated/orphaned ID references), which is what makes this a *bidirectional*
  # check rather than dimension 1's forward-only coverage-mention check.
  local target_file
  if [[ -f "$run_dir/tickets/README.md" ]]; then
    target_file="$run_dir/tickets/README.md"
  elif [[ -f "$run_dir/audit-srd.md" ]]; then
    target_file="$run_dir/audit-srd.md"
  else
    D4_SCORE=""; D4_REASON="no ticket-phase coverage map and no audit-srd.md fallback found"; return
  fi

  local target_ids target_count
  target_ids="$(grep -oE "${prefix}-[0-9]+" "$target_file" 2>/dev/null | sort -u)"
  target_count=$(printf '%s\n' "$target_ids" | grep -c . || true)

  local forward_hits=0 backward_hits=0 id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    printf '%s\n' "$target_ids" | grep -qxF -- "$id" && forward_hits=$((forward_hits + 1))
  done <<< "$srd_ids"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    printf '%s\n' "$srd_ids" | grep -qxF -- "$id" && backward_hits=$((backward_hits + 1))
  done <<< "$target_ids"

  local denom=$((srd_count + target_count))
  if [[ "$denom" -eq 0 ]]; then
    D4_SCORE=""; D4_REASON="no comparable IDs found"; return
  fi
  D4_SCORE="$(score_from_ratio "$((forward_hits + backward_hits))" "$denom")"
  D4_REASON=""
}

# ---- dimension 5: lens-jsonl-prose-agreement ---------------------------------------------
compute_dim5() {
  local run_dir="$1"
  local jsonl_files=() f
  while IFS= read -r f; do
    [[ -n "$f" ]] && jsonl_files+=("$f")
  done < <(find "$run_dir" -name 'lens-L*.jsonl' -type f 2>/dev/null | sort)

  if [[ ${#jsonl_files[@]} -eq 0 ]]; then
    D5_SCORE=""; D5_REASON="run does not include a code-audit round (no lens-L*.jsonl present)"; return
  fi

  local total=0 sum=0
  for f in "${jsonl_files[@]}"; do
    local dir base lens_n md_file jsonl_count md_count line
    dir="$(dirname "$f")"
    base="$(basename "$f" .jsonl)"
    lens_n="$(printf '%s' "$base" | sed -E 's/^lens-L//')"
    md_file="$dir/${base}.md"

    jsonl_count=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "$line" | jq -e . >/dev/null 2>&1 && jsonl_count=$((jsonl_count + 1))
    done < "$f"

    if [[ -f "$md_file" ]]; then
      md_count=$(grep -cE "^\| *L${lens_n}-[0-9]+ *\|" "$md_file" 2>/dev/null || true)
    else
      md_count=0
    fi
    [[ -z "$md_count" ]] && md_count=0

    local bigger smaller lens_score
    if [[ "$md_count" -ge "$jsonl_count" ]]; then
      bigger=$md_count; smaller=$jsonl_count
    else
      bigger=$jsonl_count; smaller=$md_count
    fi
    if [[ "$bigger" -eq 0 ]]; then
      lens_score=100
    else
      lens_score=$(score_from_ratio "$smaller" "$bigger")
    fi

    total=$((total + 1))
    sum=$(awk -v s="$sum" -v x="$lens_score" 'BEGIN{printf "%.4f", s + x}')
  done

  D5_SCORE="$(round_int "$(awk -v s="$sum" -v n="$total" 'BEGIN{printf "%.4f", s / n}')")"
  D5_REASON=""
}

# ---- JSON assembly -----------------------------------------------------------------------

build_dims_json() {
  local i=0 name score json="[" first=1
  for name in "${DIM_NAMES[@]}"; do
    score="${DIM_SCORES[$i]}"
    [[ $first -eq 1 ]] || json="$json,"
    first=0
    if [[ -n "$score" ]]; then
      json="$json{\"name\":\"$name\",\"score\":$score}"
    else
      json="$json{\"name\":\"$name\",\"score\":null}"
    fi
    i=$((i + 1))
  done
  json="$json]"
  printf '%s' "$json"
}

build_skipped_json() {
  local i=0 name reason json="[" first=1
  for name in "${DIM_NAMES[@]}"; do
    if [[ -z "${DIM_SCORES[$i]}" ]]; then
      [[ $first -eq 1 ]] || json="$json,"
      first=0
      reason="${DIM_REASONS[$i]}"
      json="$json{\"name\":\"$name\",\"reason\":$(jq -Rn --arg r "$reason" '$r')}"
    fi
    i=$((i + 1))
  done
  json="$json]"
  printf '%s' "$json"
}

# ---- main scoring entry point -------------------------------------------------------------
main_score() {
  local run_dir="$1"
  [[ -d "$run_dir" ]] || die "run directory not found: $run_dir"
  run_dir="$(cd "$run_dir" && pwd)"

  local run_json="$run_dir/run.json"
  local run_id git_sha plugin_version complete
  if [[ -f "$run_json" ]]; then
    run_id=$(jq -r '.run_id // empty' "$run_json" 2>/dev/null); [[ -n "$run_id" ]] || run_id="$(basename "$run_dir")"
    git_sha=$(jq -r '.git_sha // empty' "$run_json" 2>/dev/null); [[ -n "$git_sha" ]] || git_sha="unknown"
    plugin_version=$(jq -r '.plugin_version // empty' "$run_json" 2>/dev/null); [[ -n "$plugin_version" ]] || plugin_version="unknown"
    complete=$(jq -r 'if .complete == false then "false" else "true" end' "$run_json" 2>/dev/null)
    [[ "$complete" == "true" || "$complete" == "false" ]] || complete="true"
  else
    run_id="$(basename "$run_dir")"
    git_sha="unknown"
    plugin_version="unknown"
    complete="true"
  fi

  compute_dim1 "$run_dir"
  compute_dim2 "$run_dir"
  compute_dim3 "$run_dir"
  compute_dim4 "$run_dir"
  compute_dim5 "$run_dir"

  DIM_SCORES=("$D1_SCORE" "$D2_SCORE" "$D3_SCORE" "$D4_SCORE" "$D5_SCORE")
  DIM_REASONS=("$D1_REASON" "$D2_REASON" "$D3_REASON" "$D4_REASON" "$D5_REASON")

  # total = unweighted arithmetic mean of the non-null dimensions, / dimensions_scored
  # (read from the data), rounded to one decimal place, computed in integer tenths first
  # per the Technical Notes (jq's own float rounding is not reliable across every build).
  local sum=0 n=0 s
  for s in "${DIM_SCORES[@]}"; do
    if [[ -n "$s" ]]; then
      sum=$((sum + s))
      n=$((n + 1))
    fi
  done

  local total_json dimensions_scored
  if [[ "$n" -eq 0 ]]; then
    total_json="null"
    dimensions_scored=0
  else
    local tenths
    tenths=$(awk -v s="$sum" -v n="$n" 'BEGIN{ v=(s/n)*10; r=(v<0)?int(v-0.5):int(v+0.5); printf "%d", r }')
    total_json="$(awk -v t="$tenths" 'BEGIN{printf "%.1f", t/10}')"
    dimensions_scored=$n
  fi

  local dims_json skipped_json names_json
  dims_json="$(build_dims_json)"
  skipped_json="$(build_skipped_json)"
  names_json="$(printf '%s\n' "${DIM_NAMES[@]}" | jq -R . | jq -s .)"

  local output
  output="$(jq -n \
    --arg scorer_version "$SCORER_VERSION" \
    --argjson dimension_names "$names_json" \
    --argjson dimensions "$dims_json" \
    --argjson dimensions_scored "$dimensions_scored" \
    --argjson dimensions_skipped "$skipped_json" \
    --arg total_raw "$total_json" \
    --arg run_id "$run_id" \
    --arg git_sha "$git_sha" \
    --arg plugin_version "$plugin_version" \
    --argjson complete "$complete" \
    '{
      scorer_version: $scorer_version,
      dimension_names: $dimension_names,
      dimensions: $dimensions,
      dimensions_scored: $dimensions_scored,
      dimensions_skipped: $dimensions_skipped,
      total: ($total_raw | if . == "null" then null else tonumber end),
      run_id: $run_id,
      git_sha: $git_sha,
      plugin_version: $plugin_version,
      complete: $complete
    }')"

  printf '%s\n' "$output"
  printf '%s\n' "$output" > "$run_dir/scores.json"
}

# ---- comparison mode (AC4) -- never invoked by main_score, never automatic -----------------
# The default scoring mode above performs no comparison of any kind (AC5). This mode exists
# so the exact "refuse on scorer_version or dimensions_scored mismatch" behaviour AC4
# requires is directly testable; wiring it into a CI job is EDMV3-T39's (srd.md EDMV3-52).
cmd_compare() {
  local a="$1" b="$2"
  [[ -f "$a" ]] || die "compare: file not found: $a"
  [[ -f "$b" ]] || die "compare: file not found: $b"

  local ver_a ver_b n_a n_b
  ver_a=$(jq -r '.scorer_version // "unknown"' "$a")
  ver_b=$(jq -r '.scorer_version // "unknown"' "$b")
  n_a=$(jq -r '.dimensions_scored // -1' "$a")
  n_b=$(jq -r '.dimensions_scored // -1' "$b")

  if [[ "$ver_a" != "$ver_b" ]]; then
    echo "score-artifacts: refusing comparison -- scorer_version mismatch: $(basename "$a") is $ver_a, $(basename "$b") is $ver_b" >&2
    exit 1
  fi

  if [[ "$n_a" != "$n_b" ]]; then
    local names_a names_b
    names_a="$(jq -r '[.dimensions[] | select(.score != null) | .name] | join(",")' "$a")"
    names_b="$(jq -r '[.dimensions[] | select(.score != null) | .name] | join(",")' "$b")"
    echo "score-artifacts: refusing comparison -- dimensions_scored mismatch: $(basename "$a") scored $n_a dimensions ($names_a), $(basename "$b") scored $n_b dimensions ($names_b)" >&2
    exit 1
  fi

  jq -s '
    {
      scorer_version: .[0].scorer_version,
      dimensions_scored: .[0].dimensions_scored,
      total_delta: (.[1].total - .[0].total),
      dimension_deltas: [
        range(0; (.[0].dimensions | length)) as $i
        | {
            name: .[0].dimensions[$i].name,
            a: .[0].dimensions[$i].score,
            b: .[1].dimensions[$i].score,
            delta: (
              if (.[0].dimensions[$i].score == null or .[1].dimensions[$i].score == null)
              then null
              else (.[1].dimensions[$i].score - .[0].dimensions[$i].score)
              end
            )
          }
      ]
    }
  ' "$a" "$b"
}

# ---- dispatch ------------------------------------------------------------------------------
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --describe)
    describe
    exit 0
    ;;
  --compare)
    [[ $# -eq 3 ]] || die "usage: score-artifacts.sh --compare <a.json> <b.json>"
    cmd_compare "$2" "$3"
    exit $?
    ;;
  "")
    die "usage: score-artifacts.sh <run-dir> | --describe | --compare <a.json> <b.json>"
    ;;
  *)
    [[ $# -eq 1 ]] || die "unexpected extra argument(s): ${2:-}"
    main_score "$1"
    exit 0
    ;;
esac
