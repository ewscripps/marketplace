#!/usr/bin/env bash
# wave5-smoke.sh -- G19 new coverage: migrate-path, per-epic coverage, set-parent/add-related, .bak
# Run from repo root: bash plugins/edm/bin/tests/wave5-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"

# Shared assertions / counters (CA-014).
source "${SCRIPT_DIR}/_harness.sh"

# ---- Setup -------------------------------------------------------------------
# G21 (round-3): harness_scratch_dir honors TMPDIR and installs an EXIT/INT/TERM cleanup trap,
# unlike the bare `mktemp -d` + EXIT-only trap this replaces.
harness_scratch_dir TMP
export EDM_SRD_ROOT="$TMP/SRD"
mkdir -p "$TMP/SRD"

echo "G19 smoke check -- migrate-path, per-epic coverage, set-parent/add-related, .bak"
echo

# ---- migrate-path: valid migration -------------------------------------------
echo "migrate-path -- valid migration"
"$EDM_STATE" init MIGR1 >/dev/null
src_dir="$TMP/SRD/MIGR1"
[[ -d "$src_dir" ]] && pass "flat source dir exists before migrate" || fail "flat source dir missing"

"$EDM_STATE" migrate-path --product testprod --description my-feature MIGR1 >/dev/null
dst_dir="$TMP/SRD/testprod/MIGR1__my-feature"
[[ -d "$dst_dir" ]] && pass "product-scoped dest dir created" || fail "dest dir missing: $dst_dir"
[[ ! -d "$src_dir" ]] && pass "flat source dir removed after migrate" || fail "flat source dir still exists"

state_file="$dst_dir/.edm-state.json"
[[ -f "$state_file" ]] && pass "state file present in new location" || fail "state file missing at $state_file"

pname="$(jq -r '.product_name' "$state_file")"
desc="$(jq -r '.initiative_description' "$state_file")"
[[ "$pname" == "testprod" ]] && pass "product_name = testprod" || fail "product_name = '$pname'"
[[ "$desc" == "my-feature" ]] && pass "initiative_description = my-feature" || fail "initiative_description = '$desc'"

# CA-001 regression net: migrate-path must go through the locked/atomic/backup writer (rmw_state),
# so a .bak must exist at the new location after the field update.
[[ -f "${state_file}.bak" ]] && pass "migrate-path created .bak (locked write, CA-001)" || fail "migrate-path did not create .bak -- lock/backup bypass (CA-001)"

# ---- migrate-path: invalid inputs rejected -----------------------------------
echo
echo "migrate-path -- invalid inputs rejected"
"$EDM_STATE" init MIGR2 >/dev/null

# G50/CA-210: these are state-mutating refusals (migrate-path moves a directory and rewrites its
# state file on success) -- check_refuses_and_leaves_state proves BOTH the refusal message AND
# that MIGR2's state file was left byte-identical, not just that some rejection message appeared
# somewhere in output with the exit code silently discarded via `2>&1 || true`.
check_refuses_and_leaves_state "path-traversal product rejected" "must contain only" \
  "$TMP/SRD/MIGR2/.edm-state.json" \
  "$EDM_STATE" migrate-path --product "../evil" --description safe MIGR2

check_refuses_and_leaves_state "space in product rejected" "must contain only" \
  "$TMP/SRD/MIGR2/.edm-state.json" \
  "$EDM_STATE" migrate-path --product "has space" --description safe MIGR2

check_refuses_and_leaves_state "path-traversal description rejected" "must contain only" \
  "$TMP/SRD/MIGR2/.edm-state.json" \
  "$EDM_STATE" migrate-path --product ok --description "a/b" MIGR2

# No initiative is targeted successfully by either of the next two (usage error / unresolvable
# PREFIX) -- there is no existing state file these commands could plausibly mutate on the way to
# refusing, so check_fails alone (message + exit code) is the right assertion, not
# check_refuses_and_leaves_state.
check_fails "empty prefix rejected" "usage:" \
  "$EDM_STATE" migrate-path --product ok --description ok

check_fails "path-traversal PREFIX rejected (CA-002)" "invalid PREFIX" \
  "$EDM_STATE" migrate-path --product ok --description ok '../../evil'
[[ ! -e "$TMP/evil" ]] && pass "migrate-path PREFIX traversal moved nothing outside SRD_ROOT (CA-002)" || fail "migrate-path PREFIX traversal escaped SRD_ROOT"

# ---- migrate-path: duplicate target rejected ---------------------------------
echo
echo "migrate-path -- duplicate target rejected"
# Pre-create the destination directory to simulate a collision.
"$EDM_STATE" init MIGR4 >/dev/null
mkdir -p "$TMP/SRD/duptest/MIGR4__feat"
check_refuses_and_leaves_state "duplicate target rejected" "already exists" \
  "$TMP/SRD/MIGR4/.edm-state.json" \
  "$EDM_STATE" migrate-path --product duptest --description feat MIGR4

# ---- record-test-coverage: per-epic (4th arg) --------------------------------
echo
echo "record-test-coverage -- per-epic coverage"
"$EDM_STATE" init CVRG >/dev/null
STATE_CVRG="$TMP/SRD/CVRG/.edm-state.json"

"$EDM_STATE" record-test-coverage CVRG unit 85.5 auth >/dev/null
pct="$(jq -r '.coverage_by_epic.auth.unit.pct' "$STATE_CVRG")"
[[ "$pct" == "85.5" ]] && pass "coverage_by_epic.auth.unit.pct = 85.5" || fail "pct = '$pct'"

"$EDM_STATE" record-test-coverage CVRG unit 72 dashboard >/dev/null
pct2="$(jq -r '.coverage_by_epic.dashboard.unit.pct' "$STATE_CVRG")"
[[ "$pct2" == "72" ]] && pass "coverage_by_epic.dashboard.unit.pct = 72" || fail "pct2 = '$pct2'"

# Verify whole-initiative key is unaffected
whole="$(jq -r '.coverage_by_layer | length' "$STATE_CVRG")"
[[ "$whole" == "0" ]] && pass "coverage_by_layer empty when only per-epic recorded" || fail "coverage_by_layer length = '$whole'"

# get-coverage output includes per-epic section
cov_out="$("$EDM_STATE" get-coverage CVRG)"
check "get-coverage shows per-epic section" "Per-Epic Coverage" "$cov_out"
check "get-coverage shows auth epic" "auth" "$cov_out"
check "get-coverage shows 85.5%" "85.5" "$cov_out"

# ---- set-parent / add-related ------------------------------------------------
echo
echo "set-parent / add-related"
"$EDM_STATE" init PARENT >/dev/null
"$EDM_STATE" init CHILD >/dev/null
"$EDM_STATE" init SIBLING >/dev/null
STATE_CHILD="$TMP/SRD/CHILD/.edm-state.json"

"$EDM_STATE" set-parent CHILD PARENT >/dev/null
pp="$(jq -r '.parent_prefix' "$STATE_CHILD")"
[[ "$pp" == "PARENT" ]] && pass "parent_prefix = PARENT" || fail "parent_prefix = '$pp'"

"$EDM_STATE" add-related CHILD SIBLING >/dev/null
rp="$(jq -r '.related_prefixes[0]' "$STATE_CHILD")"
[[ "$rp" == "SIBLING" ]] && pass "related_prefixes[0] = SIBLING" || fail "related_prefixes[0] = '$rp'"

# Idempotent: adding again doesn't duplicate
"$EDM_STATE" add-related CHILD SIBLING >/dev/null
rp_len="$(jq -r '.related_prefixes | length' "$STATE_CHILD")"
[[ "$rp_len" == "1" ]] && pass "add-related is idempotent (no duplicate)" || fail "related_prefixes length = '$rp_len'"

# Non-existent parent rejected -- state-mutating (set-parent writes parent_prefix on success), so
# check_refuses_and_leaves_state proves CHILD's state file was untouched, not just that a
# rejection message appeared with the exit code discarded (G50/CA-210).
check_refuses_and_leaves_state "non-existent parent rejected" "no initiative" \
  "$STATE_CHILD" \
  "$EDM_STATE" set-parent CHILD NOPE

# Non-existent related rejected -- state-mutating (add-related appends to related_prefixes on
# success); same reasoning as above.
check_refuses_and_leaves_state "non-existent related rejected" "no initiative" \
  "$STATE_CHILD" \
  "$EDM_STATE" add-related CHILD NOPE

# HANDOFF shows linkage fields
HANDOFF="$TMP/SRD/CHILD/HANDOFF.md"
[[ -f "$HANDOFF" ]] && check "HANDOFF shows parent_prefix" "PARENT" "$(cat "$HANDOFF")" \
  || fail "HANDOFF.md not written by set-parent/add-related"

# ---- G7 path-traversal guard (PREFIX) -- CA-004 regression net for the P1 G7 fix --------------
echo
echo "G7 path-traversal -- PREFIX guard (init/set)"
# No initiative exists at any of these three malformed PREFIXes -- there is no plausible existing
# state file to prove untouched, so check_fails (message + exit code) is the right assertion
# (G50/CA-210); the filesystem-escape check immediately below already covers the mutation risk
# that matters for `init`.
check_fails "init rejects traversal PREFIX" "invalid PREFIX" \
  "$EDM_STATE" init '../escaped/INJ'
[[ ! -e "$TMP/escaped" ]] && pass "init wrote nothing outside SRD_ROOT (G7)" || fail "G7: init traversal wrote outside SRD_ROOT"
check_fails "set rejects PREFIX with slash" "invalid PREFIX" \
  "$EDM_STATE" set 'A/B' last_cmd x
check_fails "init rejects PREFIX with dots" "invalid PREFIX" \
  "$EDM_STATE" init '..'

# ---- .bak mechanism ----------------------------------------------------------
echo
echo ".bak mechanism -- backup created on write"
"$EDM_STATE" init BAKTEST >/dev/null
STATE_BAK="$TMP/SRD/BAKTEST/.edm-state.json"
BAK_FILE="${STATE_BAK}.bak"

# .bak should not exist before first mutating write (init doesn't call rmw_state for pre-existing)
# Trigger a mutating write:
"$EDM_STATE" set BAKTEST last_cmd "first write" >/dev/null
[[ -f "$BAK_FILE" ]] && pass ".bak created on first mutating write" || fail ".bak file not created at $BAK_FILE"

# .bak should reflect the pre-write state
bak_cmd="$(jq -r '.last_cmd' "$BAK_FILE")"
[[ "$bak_cmd" == "" ]] && pass ".bak reflects pre-write state (last_cmd was empty)" || fail ".bak last_cmd = '$bak_cmd'"

# Second write updates .bak to the previous live state
"$EDM_STATE" set BAKTEST last_cmd "second write" >/dev/null
bak_cmd2="$(jq -r '.last_cmd' "$BAK_FILE")"
[[ "$bak_cmd2" == "first write" ]] && pass ".bak updated to previous live state on second write" || fail ".bak last_cmd = '$bak_cmd2'"

# ---- metrics-report: G8 (n/a savings) and G20 (Phase 1 label) ---------------
# Guards against the G8 regression where zero-cost initiatives printed "0x cheaper"
# instead of "n/a", and G20 where the jq key sub produced "1Phase" instead of "Phase 1".
echo
echo "metrics-report -- G8 n/a savings and G20 Phase 1 label"
"$EDM_STATE" init MTRX >/dev/null
"$EDM_STATE" phase-start MTRX 1 >/dev/null
# EDMV3-T11: phase-complete now requires phase 1's artifact (planning.md) to be present and
# non-empty before it will record timing/cost data.
echo "planning notes" > "$TMP/SRD/MTRX/planning.md"
"$EDM_STATE" phase-complete MTRX 1 >/dev/null
MR_OUT="$("$EDM_STATE" metrics-report MTRX 2>&1)"
check "metrics-report Phase 1 row label (G20)" "Phase 1" "$MR_OUT"
check_absent "metrics-report no '1Phase' mangled label (G20)" "1Phase" "$MR_OUT"
# EDMV3-T53: the human-baseline comparison (and its G8 "n/a"/"0x cheaper" guard) moved behind
# the --with-human-baseline opt-in flag; default output carries neither the comparison nor the
# words that describe it.
check_absent "metrics-report default output has no human-baseline comparison (EDMV3-T53 AC1)" "baseline" "$MR_OUT"
MR_BASELINE_OUT="$("$EDM_STATE" metrics-report MTRX --with-human-baseline 2>&1)"
check "metrics-report --with-human-baseline savings n/a for zero-cost initiative (G8)" "n/a" "$MR_BASELINE_OUT"
check_absent "metrics-report --with-human-baseline no '0x cheaper' for zero-cost initiative (G8)" "0x cheaper" "$MR_BASELINE_OUT"

# ---- metrics-report --all: G1 both-layout enumeration (product-scoped + flat) ------
# Guards against the G1 regression where --all only walked the flat SRD_ROOT and missed
# product-scoped initiatives. MIGR1 was migrated to testprod/MIGR1__my-feature earlier;
# MTRX is flat. Both must appear in --all output.
echo
echo "metrics-report --all -- G1 product-scoped enumeration"
MR_ALL_OUT="$("$EDM_STATE" metrics-report --all 2>&1)"
check "metrics-report --all includes flat initiative (MTRX)" "MTRX" "$MR_ALL_OUT"
check "metrics-report --all includes product-scoped initiative (MIGR1)" "MIGR1" "$MR_ALL_OUT"

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
