#!/usr/bin/env bash
# _edm-datadir-lib.sh -- shared data-directory resolver (EDMV4-T17, architecture.md AD3).
#
# Meant to be `source`d, never executed directly -- the leading underscore keeps it from reading
# as a callable helper even though every script in bin/ is added to PATH while the plugin is
# enabled (the `_edm-cli-lib.sh` precedent). Do not chmod +x this file.
#
# Why this file exists: `${CLAUDE_PLUGIN_DATA}` is reserved for plugin-internal caches in
# plugins/edm/CLAUDE.md's "Architectural rules" section, but before this file, zero scripts in
# bin/ ever resolved it -- 4.1's Phase-6 marker (EDMV4-08) and 4.2's harvested pattern delta
# (EDMV4-T18) both need a writable, plugin-owned directory outside the repository working tree,
# so per AD3 this one library owns the whole question rather than each consumer inventing its own
# fall-through chain.
#
# Structural source: ECC's MIT-licensed
# ECC/skills/continuous-learning-v2/scripts/lib/homunculus-dir.sh:1-31 -- the three-step
# absolute-only chain with fall-through-on-relative. Per AD1 the adoption is mechanism-level and
# no text is copied.
#
# Exactly three public functions, no strictly-internal helper besides the leading-underscore ones
# below, and NO global variables are declared anywhere in this file (every value lives in a
# function-local, EDMV4-T17 AC3) so sourcing this alongside edm-state's own constant block (the
# region containing PATTERN_AUDIT_TYPE_ENUM_LIST) can never redefine either side's state.
#
#   edm_data_dir()
#     Prints an absolute, writable-or-creatable plugin data root, walking, in order:
#       1. ${CLAUDE_PLUGIN_DATA}          if absolute and creatable
#       2. ${XDG_DATA_HOME}/edm           if XDG_DATA_HOME is absolute and creatable
#       3. ${HOME}/.local/share/edm       if creatable
#       4. (unresolvable)                 prints the empty string; callers degrade
#     A relative CLAUDE_PLUGIN_DATA or XDG_DATA_HOME is skipped outright, never used as-is.
#     Exit status is always 0 -- even the terminal empty-string case is not a failure, it is a
#     signal for the caller to degrade against.
#     "Creatable" is tested with builtin `[[ -d ]]` / `[[ -w ]]` only, walking up to the nearest
#     existing ancestor directory in pure bash -- this function never invokes `mkdir` and never
#     writes anything to disk itself (EDMV4-T17 AC9: with CLAUDE_PLUGIN_DATA unset this must not
#     touch the repository working tree). Creating ${data}/patterns/ or ${data}/run/ on first
#     actual write is each consumer's own job (EDMV4-08, EDMV4-T18) -- out of scope here.
#
#   edm_project_key()
#     Prints a filesystem-safe encoding of the current project's root directory: resolves
#     ${CLAUDE_PROJECT_DIR} when it names a directory, else `git rev-parse --show-toplevel`, else
#     `pwd`, then replaces '/' and '.' with '-' using pure bash parameter expansion (not `tr`) --
#     the CA-448 precedent from check_permission_rules, so a hook invoked from a subdirectory
#     keys the same path the edm-state writer created. `git` is spawned only when
#     CLAUDE_PROJECT_DIR is unset or does not name a directory (EDMV4-T17 AC7).
#
#   edm_marker_path()
#     Prints "${data}/run/<key>.phase6" where <data> is edm_data_dir()'s result and <key> is
#     edm_project_key()'s result. Writes nothing; a pure string composition.
#
# Subprocess note (EDMV4-T17 AC7): "spawns zero subprocesses" throughout this file means "invokes
# no external binary" (no `git`, no `tr`, no `stat`) -- not "forks no subshell for command
# substitution", which is this codebase's universal idiom for consuming a `print`-style function
# (session_dir_for_cwd, get_session_tokens_since, etc. are all consumed the same way). Only
# edm_project_key() may exec an external binary, and only the one named above, only on the stated
# condition.
#
# Bash 3.2 floor (C1): no bash-4-only associative-array declarations, no bash-4-only upper-case
# parameter expansion, no bash-4-only whole-array-from-stdin builtins, no process substitution in
# a loop condition. Required binaries stay bash, jq, git (C2) -- this file itself needs none of
# the three beyond the conditional `git rev-parse` above. (Deliberately not spelling out the
# bash-4 construct names literally here -- EDMV4-T17 AC6's smoke test greps this file for those
# exact tokens and must fail only on real usage, never on this sentence describing the rule.)

# _edm_datadir_creatable <absolute-path>
#   True if <absolute-path> already exists and is writable, or does not exist but its nearest
#   existing ancestor is writable. Pure bash: no subprocess, no filesystem mutation.
_edm_datadir_creatable() {
  local p="$1"
  while [[ ! -d "$p" ]]; do
    if [[ "$p" == */* && "$p" != / ]]; then
      p="${p%/*}"
      [[ -n "$p" ]] || p="/"
    else
      p="/"
      break
    fi
  done
  [[ -w "$p" ]]
}

# edm_data_dir -- see file header. Always exits 0.
edm_data_dir() {
  local candidate

  candidate="${CLAUDE_PLUGIN_DATA:-}"
  if [[ "$candidate" == /* ]] && _edm_datadir_creatable "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="${XDG_DATA_HOME:-}"
  if [[ "$candidate" == /* ]]; then
    candidate="${candidate}/edm"
    if _edm_datadir_creatable "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="${HOME:-}/.local/share/edm"
  if [[ "$candidate" == /* ]] && _edm_datadir_creatable "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  printf '%s\n' ""
  return 0
}

# edm_project_key -- see file header. Always exits 0.
edm_project_key() {
  local dir="${CLAUDE_PROJECT_DIR:-}"

  if [[ -z "$dir" || ! -d "$dir" ]]; then
    dir="$(git rev-parse --show-toplevel 2>/dev/null)" || dir=""
    if [[ -z "$dir" ]]; then
      dir="$(pwd)"
    fi
  fi

  local key="${dir//\//-}"
  key="${key//./-}"
  printf '%s\n' "$key"
}

# edm_marker_path -- see file header. Always exits 0; prints nothing meaningful if edm_data_dir
# is unresolvable (the caller is expected to treat a path rooted at "/run/<key>.phase6" as
# unusable in that case, matching edm_data_dir's own "empty string, callers degrade" contract).
edm_marker_path() {
  local data key
  data="$(edm_data_dir)"
  key="$(edm_project_key)"
  printf '%s\n' "${data}/run/${key}.phase6"
}
