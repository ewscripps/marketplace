I have completed the audit. I could not write files (no Write tool in my delivered tool set -- the CA-130 class), so both halves follow.

---

## Findings (L4: Test Quality)

### Round-9 remediation verification (Priority 1) -- summary

Verified correct and regression-free at their named sites: **CA-454** (three substring exit-code checks converted to numeric equality at `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:2630, :4625, :4647`), **CA-458** (`wave6-smoke.sh:206` is now exact string equality, and the two sibling fix comments at `:215`/`:226` that cite it as "the already-correct shape" are now truthful), **CA-401(b)** (`wave7-smoke.sh:1302-1304` guards the terminal `grep` and floors both sides `^[1-9][0-9]*$` before comparing), **G64 needle retarget** (`wave7-smoke.sh:6910-6913`; both needles match the shipped CLAUDE.md delegate wording), and **CA-467** (`wave7-smoke.sh:1662-1686` genuinely deduplicates all twelve schema copies and carries a working positive control). Two new blocks -- **CA-471** (`wave6-smoke.sh:866-910`) and the **CA-441** grants rule -- landed with material coverage holes, filed below.

---

**P1 -- `wave6-smoke.sh:877` -- the CA-471 completeness gate's two decisive behaviors both survive a one-line mutation; the suite cannot tell the new gate from a catastrophically broken one**

File: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave6-smoke.sh:866-910`, covering `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:4449-4472`.

Two independent mutations to the brand-new gate leave all six CA-471 assertions -- and the whole 2182-assertion suite -- green:

*(a) Unconditional downgrade.* Moving `ca471_downgrade="partial"` (`edm-state:4469`) out of the `if [[ -n "$_missing" ]]` guard while leaving it inside the manifest guard makes **every** code round that has a pass directory record `round_type=partial`, so no initiative can ever converge again. Nothing fails, because the only "fully-backed" case (`CA471OK`) is started with `--lenses L1,L2` at `:875` -- its round is **already** `partial` -- and its sole assertion at `:877` is `check_absent ... "CA-471"` on the warn text, never on `round_type`. There is no case anywhere that completes a **full** code round with all its JSONL present and asserts the round is still `full` afterwards. I confirmed the T27 `round_type=full` assertions (`wave6-smoke.sh:3234, :3251, :3259`) are all taken immediately after `audit-round-start` and never after `audit-round-complete`, so they cannot catch this either.

*(b) Deleted JSON-validity arm.* Deleting `|| ! jq empty "$_lens_file"` from the condition at `edm-state:4463` also leaves all six assertions passing, because the only miss fixture (`:884`) is an **empty** file (`: >`), which the sibling `[[ ! -s ]]` catches on its own. Of the three input classes the gate's own comment claims ("missing/empty/unparseable", `edm-state:4442`), only *empty* is exercised -- and the class that motivated the guard is *missing*: pass-7 of this initiative shipped eleven prose reports and **zero** JSONL files.

This is not CA-453 (CA-389/CA-390's unwritten tests) or CA-425 (`--accept-p2-debt`'s guard) -- different gate, different code, new in this batch. Fix: (i) add a case that runs `audit-round-start <PFX> code` with no `--lenses`, lands a parseable JSONL for every lens in the manifest, completes the round, and asserts `round_type == "full"` **after** completion; (ii) split the miss fixture into three lenses -- one file absent, one empty, one present-but-unparseable (e.g. `printf 'not json\n'`) -- and assert all three lens IDs appear in the single warn's `for: ` list.

---

**P2 -- `wave7-smoke.sh:364-396` -- the new CA-441 `Task`-grant rule shipped with no must-fail case, and its only coverage is an assertion the rule cannot influence**

File: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:364-396` (absent case), covering `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-check-grants:506-517`.

`scan_skill_tool_usage` gained a second positive rule this batch. The established must-fail shape sits 130 lines above it: `t03_ac6_case` copies the tree to scratch, strips `, AskUserQuestion$` from one skill's `allowed-tools`, then asserts exit 1, the file name, and the class name (`:388-391`). That case exercises the **AskUserQuestion** rule only. Nothing was added for `Task`.

Because CA-441's own fix granted `Task` to all twelve skills, `needs_task=1 && ! has_tool "$allowed" "Task"` (`edm-check-grants:515`) is false everywhere, so `mark_and_maybe_report skill ... Task` is **never reached** on the live tree. The rule's only coverage is the family of "edm-check-grants exits 0 against the live tree" assertions (`wave7-smoke.sh:339, :2860, :3034, :3171`) -- all of which pass identically whether the rule works or does not exist. If the detection regex `(^|[^a-zA-Z])spawn[^a-zA-Z].*edm-|^Agent: edm-` (`:509`, non-trivially escaped, two alternatives, `grep -qiE`) were mis-escaped, or `has_tool` mishandled `Task`, the rule would silently protect nothing, permanently -- and the next skill added would reproduce exactly the CA-441 defect it was built to prevent. Note the `^Agent: edm-` alternative is anchored at line start and is currently carried entirely by the first alternative; no control proves it can match at all.

This is the CA-441 remediation's own prescription ("Separately extend `edm-check-grants` source 4 ... otherwise the next skill added has the same hole") landing its code half without its test half -- the CA-453 shape at a new site. Fix: clone `t03_ac6_case` for the new rule (strip `, Task` from a scratch copy of `skills/test/SKILL.md`, assert exit 1 plus the reported class), and add an arm control feeding one synthetic line per regex alternative, failing by alternative name.

---

**P2 -- `wave6-smoke.sh:811` -- the CA-426 regression fixture positively pins "an initiative with zero recorded audit rounds converges via `--accept-p2-debt`", and no case asserts any boundary on it**

File: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave6-smoke.sh:800-815`.

`PDEBT6` is `init`-ed and given a ledger, then `approve-gate PDEBT6 code-audit --accept-p2-debt` is run with **no** `audit-round-start` and **no** `audit-round-complete` at all. That is the point -- it reproduces the zero-recorded-rounds stderr warn CA-426 was about. But `cmd_audit_converged`'s zero-rounds arm *warns and proceeds*, so stdout carries the `not converged: ` prefix, the override engages, and `:812` asserts **exit 0** while `:814-815` asserts the success message. The suite now positively certifies that an initiative which has never run a code-audit round can be converged.

The test-quality problem is the asymmetry: CA-425's negative set added this batch covers a partial round (`:774`), an invalid ledger (`:786`), the wrong gate (`:792`) and an unrecognized argument (`:795`) -- but has no zero-round member, even though zero-round is the one class the CA-426 fix deliberately *re-enabled*. The code's own narrowing comment at `edm-state:2236` enumerates "a partial round, invalid JSONL, or invalid status line" and silently omits the arm that proceeds; and CA-471 landed in the same batch specifically to make round completeness verifiable. Whether zero-round convergence is intended is an L9/spec question -- what L4 owns is that the behavior is now locked in by a passing assertion with no companion case stating the boundary either way.

Fix: rebuild the CA-426 stream-separation regression on a fixture with a real completed round plus an independently-induced stderr warn, so the regression test no longer depends on the zero-round shape; then add an explicit case for zero rounds asserting whichever behavior is decided, with a comment naming the decision.

---

**P2 -- `.gitlab-ci.yml:524` -- `test:state-validate` is a blocking job that prints `OK` after validating nothing, with no floor**

File: `/Users/darryl.porter/projects/marketplace/.gitlab-ci.yml:508-550`.

The script runs under `set -u` only (`:516`; no `-e`, deliberately POSIX-`sh`-safe). `edm-state list --paths > "$LIST_FILE"` at `:524` has its exit status discarded. If enumeration fails or returns nothing -- a broken `EDM_SRD_ROOT`, a relocated `SRD/` tree, a `jq`/layout regression in `list --paths` -- the `while` loop body never executes, `COUNT` stays 0, `FAIL` stays 0, and the job prints `state-validate: 0 initiative(s) checked` (`:545`) followed by `test:state-validate: OK` (`:550`) and exits 0. A blocking gate reports green having checked zero initiatives, and the printed count is the operator's only signal -- with nothing asserting it.

This plugin already fixed exactly this class one directory over: CA-016 added the `_MIN_SUITE_COUNT` floor and the missing-preferred-suite check to `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/run-all.sh:70-91`, with the comment "a zero-suite guard above catches total deletion, but does nothing if a named suite ... is deleted". No equivalent exists here. Fix: capture and check `edm-state list --paths`'s status on the same statement, and fail the job when `COUNT` is 0 (or below a small committed floor), naming enumeration as the cause rather than printing `OK`.

---

**P2 -- `.gitlab-ci.yml:748` -- `eval:nightly` still skips scoring *and* comparison silently when the run directory is absent; the CA-443 fix closed one cause, not the class**

File: `/Users/darryl.porter/projects/marketplace/.gitlab-ci.yml:747-768`.

Both blocks are `if [ -n "$RUN_DIR" ] ... ; fi` with **no `else` arm**, and `RUN_DIR` is re-derived independently at `:749` and `:759` from `ls -td .../runs/*/ 2>/dev/null | head -1`. CA-443 named this exact downstream consequence ("scoring and the baseline comparison are skipped WITH NO MESSAGE, and eval:nightly reports success having evaluated nothing"), and its remediation went entirely into `run-eval.sh` (clamping `EDM_EVAL_KEEP_RUNS=0` to 1). Any *other* reason the directory is absent -- a changed output root, an artifact-cleanup step, a run written elsewhere -- still produces a job that scores nothing, compares nothing, says nothing about either, and reaches the end without incident. This is the residual half of a fix whose code landed, filed separately rather than as a re-file of CA-443 (same pattern the ledger uses for CA-434/CA-435/CA-438). Severity held at P2 because the job carries `allow_failure: true`, so the loss is an advisory tripwire silently reporting nothing rather than a blocking gate.

Fix: derive `RUN_DIR` once, assert it non-empty and that `scores.json` exists, and give both blocks `else echo ...; exit 1` arms so an unscored or uncompared run is a named failure.

---

## Noted / Not Actionable

- **`wave7-smoke.sh:1684` (CA-467 control asserts a literal 2)** -- `ca467_ctl_unique -eq 2` rather than `ca467_unique + 1`, so when the real identity check already fails, the control also fails with the misleading "positive control failed" message. Both fail, so nothing passes wrongly; diagnostics only.
- **`wave7-smoke.sh:1664` (`_ca467_extract` uses `head -1`)** -- a second, divergent schema copy inside the *same* file would be invisible. Verified no file currently carries two; the tree-wide grep returns exactly one per file.
- **`wave7-smoke.sh:8227` (CA-472 tripwire uses `grep -v '^\s*#'`)** -- `\s` is a GNU extension; on BSD grep (macOS, the documented primary dev platform) it degrades to `^s*#`, filtering only column-0 comments. Direction is toward a false **failure**, never a false pass, and no indented comment in the three scanned files contains the needle today.
- **`wave6-smoke.sh:869` (`pass-1_2026-08-16` hardcoded in the CA-471 fixture)** -- not a real-time dependency. `edm-state:4453` resolves the pass directory by the glob `pass-${round_num}_*`, so the literal date never has to match the run date. Checked specifically because a date-shaped literal in a new fixture is the classic shape.
- **`wave6-smoke.sh:870` / `wave7-smoke.sh:1620` (manifest fixture realism)** -- the CA-471 and T24 AC0 fixtures use the real `lenses-run.txt` shape (a `Round type:` header plus one bare `L<N>` per line), byte-compatible with the actual `pass-7_2026-08-10/lenses-run.txt` on disk. The manifest parser is tested against a representative artifact, not a convenient one.
- **`wave7-smoke.sh:8167` (`count_matches` with no path-existence guard at the new CA-460/CA-472 sites)** -- same exit-2-collapse false-pass class as CA-459 and CA-401, which are in the documented D60 debt set; recorded here only so the round notes that the debt class acquired new sites this batch, and deliberately **not** re-filed.
- **`agents/edm-audit-synthesizer.md:162, :195` (`spec_swept` and the `tooling-notes.md` consumer)** -- CA-416's new ledger field and CA-466's new synthesizer read both landed with no smoke assertion anywhere. Prompt-surface-only changes with no executable path; folded here rather than filed, since the "prescribed durability pin never landed" class is already tracked and the consequence is not a false-passing test.
- **`wave6-smoke.sh:774-797` (CA-425's four new negative cases)** -- all four use `check_refuses_and_leaves_state`, which proves non-zero exit, the message substring, and state byte-identity from a single real invocation. Correct shape; no finding.
- **`wave7-smoke.sh:679-681` (CA-462 `known-gap-recall`)** -- asserts the literal hand-computed `33` (2 of 6 gaps) rather than `!= null`, and pairs it with a skip-path assertion at `:663`. This is the expected-value shape CA-039 established; no finding.

---

