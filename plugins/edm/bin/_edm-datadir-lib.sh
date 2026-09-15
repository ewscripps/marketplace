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
# Four public functions -- the three documented immediately below plus edm_data_dir_claim(),
# documented at its own definition -- no strictly-internal helper besides the leading-underscore
# ones, and NO global variables are declared anywhere in this file (every value lives in a
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
#     `pwd`; NORMALIZES whichever of those three branches supplied it through `cd ... && pwd -P`
#     (EDMDS-11 AC2, CA-109), falling back to the unnormalized value when `cd` fails; then replaces
#     '/' and '.' with '-' using pure bash parameter expansion (not `tr`) -- the CA-448 precedent
#     from check_permission_rules, so a hook invoked from a subdirectory keys the same path the
#     edm-state writer created. The `pwd -P` step makes a logical (symlinked) and a physical
#     spelling of ONE project produce ONE key, which is what stops a Phase-6 gate armed under one
#     spelling from being invisible under the other. `git` is still spawned only when
#     CLAUDE_PROJECT_DIR is unset or does not name a directory (EDMV4-T17 AC7) -- `cd` and `pwd`
#     are builtins, so normalization added no external binary.
#
#   edm_marker_path()
#     Prints "${data}/run/<key>.phase6" where <data> is edm_data_dir()'s result and <key> is the
#     same key edm_project_key() returns. Almost always a pure string composition -- the ONE
#     exception is the one-time key migration described at _edm_migrate_run_keys() below, which
#     renames run/ entries left under the pre-normalization key and writes nothing at all when
#     there are none (EDMDS-11 AC8b).
#
# Subprocess note (EDMV4-T17 AC7): "spawns zero subprocesses" throughout this file means "invokes
# no external binary" (no `git`, no `tr`, no `stat`) -- not "forks no subshell for command
# substitution", which is this codebase's universal idiom for consuming a `print`-style function
# (session_dir_for_cwd, get_session_tokens_since, etc. are all consumed the same way). The
# resolution path honours that strictly: `git` is the only binary it may exec, on the one stated
# condition. Two WRITING paths are the stated exceptions, neither of them on a resolution path:
# edm_data_dir_claim() calls `mkdir` (it has since EDMV4-T17 AC9 -- this note used to say no
# function but edm_project_key() may exec anything, which that function already contradicted), and
# _edm_migrate_run_keys() calls `mv` on the one-time upgrade path described at its own definition.
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

# EDM_DATA_OWNER_SENTINEL -- the basename of the file that marks a data directory as EDM's own.
# Deliberately a constant expression used inline below rather than a global variable: this file
# declares NO globals (EDMV4-T17 AC3), so the name is repeated in the two places that need it and
# named here in prose instead.
#
# _edm_datadir_owned <absolute-path>
#   True if <absolute-path> is EDM's to write into: it does not exist yet, OR it is empty, OR it
#   carries an `.edm-owned` sentinel. False when it exists, holds other content, and has no
#   sentinel -- that directory belongs to some other plugin.
#
#   Why this exists (CA-134, decision D46): `${CLAUDE_PLUGIN_DATA}` is plugin-specific BY CONTRACT,
#   and when EDM runs as an installed plugin the host sets it correctly. But EDM is routinely
#   invoked by explicit path -- `bash plugins/edm/bin/edm-state ...`, and every hook consumer --
#   and in those contexts the host has no reason to have pointed it at EDM. EDM therefore inherited
#   whatever plugin happened to be active and wrote its harvested pattern library into that
#   plugin's directory. Reproduced live: 133 EDM findings landed in
#   `.../plugins/data/copilot-studio-skills-for-copilot-studio/patterns/code-audit.md` while three
#   correctly-named edm-* directories sat unused.
#
#   Namespacing was tried first and is WRONG: `${CLAUDE_PLUGIN_DATA}/edm` is still inside the
#   foreign plugin's tree, so it tidies the path without fixing ownership. The test has to be
#   "is this mine", which a path shape cannot answer and a sentinel can.
#
#   Pure bash, no subprocess, and NO WRITES (AC9: with CLAUDE_PLUGIN_DATA unset this must not touch
#   anything). Creating the sentinel is the first writing consumer's job, alongside the
#   `patterns/` and `run/` directories it already creates -- exactly the split this file already
#   uses for directory creation.
_edm_datadir_owned() {
  local p="$1" entry
  # Does not exist yet -> nobody owns it, EDM will create it.
  [[ -d "$p" ]] || return 0
  # Already claimed by EDM.
  [[ -e "${p}/.edm-owned" ]] && return 0
  # C-4 backward compatibility: a directory carrying EDM's OWN footprint is EDM's, even
  # with no sentinel. Every data directory that predates this change is exactly that shape,
  # and a strict sentinel-only test would silently abandon all of them -- a user would find
  # their harvested pattern library apparently empty because EDM had quietly moved to a new
  # root. run/ holds <project-key>.phase6 markers and patterns/ holds <type>-audit.md; both
  # are names this plugin creates and nothing else does.
  #
  # Residual, stated rather than hidden: a foreign directory EDM has ALREADY polluted
  # carries patterns/ too, so it keeps being accepted until a human deletes it. This test
  # stops the pollution spreading to new directories; it cannot un-write what already
  # landed. The sentinel is what makes future ownership unambiguous.
  [[ -d "${p}/run" || -d "${p}/patterns" ]] && return 0

  # Exists but empty -> unclaimed, safe to adopt. Globs rather than `ls` (no subprocess). With
  # nullglob off, a non-matching pattern expands to itself, which -e/-L correctly reject.
  for entry in "$p"/* "$p"/.[!.]* "$p"/..?*; do
    if [[ -e "$entry" || -L "$entry" ]]; then
      return 1
    fi
  done
  return 0
}

# edm_data_dir -- see file header. Always exits 0.
edm_data_dir() {
  local candidate

  candidate="${CLAUDE_PLUGIN_DATA:-}"
  # CA-134/D46: creatable is not sufficient -- a foreign plugin's data directory is
  # perfectly writable. The ownership test is what keeps EDM out of it.
  if [[ "$candidate" == /* ]] && _edm_datadir_creatable "$candidate" \
     && _edm_datadir_owned "$candidate"; then
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

# _edm_project_root_pair -- print exactly two lines: the resolved project root EXACTLY as the
# environment spelled it, then that same root resolved PHYSICALLY. This is the only place in this
# file the three-branch resolution chain is written; edm_project_key() and the run/ key migration
# below both read it, so the two can never derive different roots from the same environment.
#
# EDMDS-11 AC2 (CA-109): the physical line is what the key is encoded from. The normalization is
# applied to WHICHEVER branch supplied the directory -- not only to the `pwd` fallback, which is
# the one branch a symlinked CLAUDE_PROJECT_DIR never reaches; normalizing only there would have
# left the dominant host-set case unfixed while a fixture driving the fallback went green.
#
# The cost is one extra subshell and zero external binaries: `cd` and `pwd` are bash builtins, so
# EDMV4-T17 AC7's contract (git is the only binary this file may exec, and only when
# CLAUDE_PROJECT_DIR is unset or names no directory) is unchanged, and the failing-git stub that
# pins it still passes. When `cd` fails -- an unreadable or vanished directory -- the unnormalized
# value is used, because a key derived from the spelling we were given beats no key at all.
#
# Why it matters beyond tidiness: the key names the Phase-6 marker, so two spellings of ONE project
# produced two keys, and a gate armed under one spelling was invisible from the other. That is the
# non-hostile divergence -- no attacker required, just a symlinked path, which on macOS includes
# anything under /tmp, /var or TMPDIR.
_edm_project_root_pair() {
  local dir="${CLAUDE_PROJECT_DIR:-}" phys

  if [[ -z "$dir" || ! -d "$dir" ]]; then
    dir="$(git rev-parse --show-toplevel 2>/dev/null)" || dir=""
    if [[ -z "$dir" ]]; then
      dir="$(pwd)"
    fi
  fi

  phys="$(cd "$dir" 2>/dev/null && pwd -P)" || phys=""
  if [[ -z "$phys" ]]; then
    phys="$dir"
  fi

  printf '%s\n%s\n' "$dir" "$phys"
}

# edm_project_key -- see file header. Always exits 0. Writes nothing.
edm_project_key() {
  local pair root
  pair="$(_edm_project_root_pair)"
  root="${pair#*$'\n'}"

  local key="${root//\//-}"
  key="${key//./-}"
  printf '%s\n' "$key"
}

# _edm_migrate_run_keys <data-dir> -- print the CURRENT project key, having first renamed any
# ${data}/run/ entry still filed under the PRE-NORMALIZATION key onto it. One resolution pass
# serves both keys, so the migration can never disagree with edm_project_key() about either.
#
# EDMDS-11 AC8b: normalization converges two spellings of one project onto the physical one, which
# by construction MOVES the key for the losing spelling. A marker left behind under the old key is
# not merely litter -- it is a disabled gate. edm-gateguard finds no marker under the new key and
# allows every edit, while EDMDS-20's reaper cannot collect the orphan either, because that reaper
# removes a `.phase6` only when its recorded initiative_dir has gone, and for a live initiative
# that directory still exists. So the rename happens here rather than waiting for the next
# `phase-start 6` to rewrite the key: that route leaves the old entry in place (the orphaning this
# forbids) AND leaves a user mid-Phase-6 ungated until they happen to re-run it.
#
# All three per-key run/ entries move together -- `.phase6`, `.checked` and `.denials` -- because
# gateguard composes the latter two from the same key and would otherwise restart a session's
# first-touch and denial-budget accounting silently.
#
# Cost and safety: when the two spellings agree (any project whose path contains no symlink) this
# is one string comparison and returns immediately -- no test, no write. The rename itself is the
# only write, it happens only when a legacy entry exists AND the new name is free, and it never
# clobbers: an existing entry under the new key always wins, since it is the one the running
# gateguard is already reading. `mv` is POSIX and ships everywhere bash does; it is not a new
# required binary in the sense CLAUDE.md's bash/jq/git contract means, and it is reached only on
# this one-time upgrade path.
#
# Stated residual, because a half-stated rule is how CA-109 arose in the first place: when BOTH
# names are already populated, the legacy entry is left in place rather than removed. That case
# cannot arise from a single project's own upgrade -- the migration runs at the first marker
# resolution, before anything can have written under the new key -- so it means two distinct
# legacy spellings converged onto one physical root, where the new-key entry is authoritative and
# the leftover is unreachable by any post-change code. Destroying a marker file from a library
# function on a READ path is a worse failure than leaving one stale file behind, so this one is
# left, deliberately, and recorded rather than hidden.
_edm_migrate_run_keys() {
  local data="$1" pair legacy_root phys_root legacy current suffix old new

  pair="$(_edm_project_root_pair)"
  legacy_root="${pair%%$'\n'*}"
  phys_root="${pair#*$'\n'}"

  legacy="${legacy_root//\//-}"
  legacy="${legacy//./-}"
  current="${phys_root//\//-}"
  current="${current//./-}"

  if [[ "$legacy" != "$current" && -n "$data" && -d "${data}/run" ]]; then
    for suffix in phase6 checked denials; do
      old="${data}/run/${legacy}.${suffix}"
      new="${data}/run/${current}.${suffix}"
      if [[ -e "$old" && ! -e "$new" ]]; then
        mv "$old" "$new" 2>/dev/null || true
      fi
    done
  fi

  printf '%s\n' "$current"
}

# edm_marker_path -- see file header. Always exits 0. EDMV4-T12 AC9: when edm_data_dir() is
# unresolvable (empty string), this prints a genuinely empty string too, rather than the
# misleading-looking "/run/<key>.phase6" a bare concatenation would produce -- every caller
# (edm-state's marker helpers, edm-gateguard) treats a non-empty return as a real, usable path,
# so a caller-side special case for "well-formed but actually unusable" would be fragile and is
# not required: `[[ -n "$marker" ]]` alone is the single-condition "marker is usable" check
# every consumer already uses for edm_data_dir() itself.
edm_marker_path() {
  local data key
  data="$(edm_data_dir)"
  [[ -n "$data" ]] || { printf '%s\n' ""; return 0; }
  # EDMDS-11 AC8b: the key comes back from the migration helper rather than from edm_project_key()
  # directly. This is the one chokepoint BOTH the marker's writer (edm-state) and its reader
  # (edm-gateguard) traverse, so it is the only place a pre-normalization marker can be picked up
  # before the gate concludes it is absent. The helper returns the identical key edm_project_key()
  # would, and writes nothing at all unless a legacy-key entry is actually sitting there.
  key="$(_edm_migrate_run_keys "$data")"
  printf '%s\n' "${data}/run/${key}.phase6"
}

# edm_data_dir_claim -- create the resolved data directory if needed and drop the `.edm-owned`
# sentinel that _edm_datadir_owned() reads on every later run.
#
# This is the ONLY function in this file that writes anything. edm_data_dir() itself still writes
# nothing (EDMV4-T17 AC9), which is why the claim is a separate, explicitly-called function rather
# than a side effect of resolution: resolution happens on every gateguard invocation including the
# marker-absent fast path, and that path must stay at one exec and zero writes (EDMV4-T07 AC8).
# Consumers call this at their first genuine write, alongside the patterns/ and run/ directories
# they already create.
#
# Idempotent, and never fails its caller: a claim that cannot be written degrades to silence and
# the caller proceeds, matching the posture every other data-dir consumer already uses. The cost of
# a failed claim is only that the next run re-evaluates ownership from scratch.
edm_data_dir_claim() {
  local data
  data="$(edm_data_dir)"
  [[ -n "$data" ]] || return 0
  [[ -e "${data}/.edm-owned" ]] && return 0
  mkdir -p "$data" 2>/dev/null || return 0
  {
    printf '%s\n' "EDM plugin data directory."
    printf '%s\n' "Do not remove: bin/_edm-datadir-lib.sh reads this file to confirm the directory"
    printf '%s\n' "is EDM-owned before writing here, so EDM never writes into another plugin's"
    printf '%s\n' "data directory when it inherits that plugin's CLAUDE_PLUGIN_DATA (CA-134)."
  } > "${data}/.edm-owned" 2>/dev/null || true
  return 0
}
