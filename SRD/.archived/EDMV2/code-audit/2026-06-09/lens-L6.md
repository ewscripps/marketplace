# Lens L6: Documentation Accuracy — Round 2 (2026-06-09)

## Summary

The state-write rewrite is well-commented and most remediated messages are accurate: G3's checkpoint comment, the lock-timeout `die`, the path-traversal rejection, the `n/a` savings, the `Phase N` label, the archive-refused message, and the `record-task-duration` reserved-no-op comment all match the code. **However, the Round-1 G16/G22 documentation batch was only PARTIALLY remediated** — several fixes landed in CLAUDE.md/README tables but were never applied to the specific file:line the findings named. The single highest-impact item is the **README `code-audit/` directory tree, which still shows the wrong layout** and now actively contradicts both CLAUDE.md and the shipped code. The rewrite also introduced one new regression: `edm-state --help` truncates the last 5 subcommands.

Total: 8 findings (0 P0, 0 P1, 8 P2). No data-loss-class doc errors.

## Findings

### [P2] README `code-audit/` tree shows wrong directory layout, contradicting code and CLAUDE.md — README.md:104-106
**Evidence:** README.md:104-106 shows `code-audit/ └── {YYYY-MM-DD}/ ├── lens-L1.md … └── REMEDIATION.md`. The code produces and reads `code-audit/pass-{N}_{YYYY-MM-DD}/`: `skills/code-audit/SKILL.md:17,40` writes `OUTPUT_DIR=".../code-audit/pass-${N}_$(date +%Y-%m-%d)/"`, and `bin/edm-state:1561` globs `"${_dir}/code-audit"/pass-*/REMEDIATION.md`. CLAUDE.md:74 correctly documents `code-audit/pass-{N}_{YYYY-MM-DD}/`. README is the lone outlier and omits `findings-ledger.md` and `lenses-run.txt`. This is Round-1 G16 item 2, fixed in CLAUDE.md but never corrected in README.
**Why it matters:** An operator inspecting audit output by the README's path won't find it where the plugin writes it, and the README now contradicts CLAUDE.md and the SKILL. (Note: this meta-audit's own artifacts live at `SRD/EDMV2/code-audit/2026-06-08/` and `2026-06-09/` — hand-created date-dirs, not the skill's `pass-N_` convention.)
**Suggested fix:** Replace README.md:104-106 with the CLAUDE.md:72-77 tree.

### [P2] `edm-test-contract` agent description omits GraphQL — agents/edm-test-contract.md:4
**Evidence:** Line 4 `description:` says "OpenAPI/Swagger" with no GraphQL. The body (lines 17,35) and README:61 / CLAUDE.md:262 / CHANGELOG:75 were updated to "OpenAPI/GraphQL"; the frontmatter wasn't. Round-1 G22 L6-09 cited precisely this line.
**Suggested fix:** Edit line 4 to "...OpenAPI/Swagger or GraphQL schema...".

### [P2] CLAUDE.md says test-coverage-auditor disallows `Write`, but the agent allows it — CLAUDE.md:271
**Evidence:** CLAUDE.md:271 states `disallowedTools: Write, Edit, NotebookEdit`. The agent (`agents/edm-test-coverage-auditor.md:10-11`) has `tools: Read, Write, Bash, Glob, Grep, TodoWrite` and `disallowedTools: Edit, NotebookEdit` — `Write` is allowed (it must write `test-coverage.md`). Round-1 G16 item 8: agent fixed, CLAUDE.md not.
**Suggested fix:** Change CLAUDE.md:271 to `disallowedTools: Edit, NotebookEdit` (Write required).

### [P2] `edm-state --help` truncates the last 5 subcommands — bin/edm-state:1966
**Evidence:** The help branch runs `sed -n '2,34p' "$0"`. The usage header documents 36 subcommands across lines 4-39; lines 35-39 are cut: `resolve-dir`, `set-parent`, `add-related`, `update-patterns`, `lint`. All 36 are dispatched and documented in the header; only the `--help` slice is short — a likely regression from the rewrite shifting line numbers.
**Suggested fix:** Change to `sed -n '2,39p' "$0"` (or anchor to the header block).

### [P2] code-audit SKILL HITL-gate step says "P1/P2/P3" — contradicts the same skill's canonical-scale mandate — skills/code-audit/SKILL.md:186
**Evidence:** Line 186 says "Summarize: P1/P2/P3 counts…", but line 127 mandates the canonical P0/P1/P2/NOTED scale and the table at 137-144 uses it. The synthesizer emits P0/P1/P2/NOTED, so the gate-summary instruction is self-contradictory.
**Suggested fix:** Change line 186 to "P0/P1/P2 counts (+ NOTED count)".

### [P2] README understates which commands the gate hook blocks — README.md:85
**Evidence:** README:85 lists `srd`, `tickets`, `implement`; `hooks/hooks.json` registers five matchers including `audit-srd` and `audit-tickets`. CLAUDE.md:390 lists all five.
**Suggested fix:** Add the two audit commands or say "the SRD/audit/ticket/implement phase commands."

### [P2] README `.edm-state.json` tree comment omits "mode fields" — README.md:108
**Evidence:** README:108 says "gate approvals, phase timestamps"; CLAUDE.md:85 says "…, mode fields". Round-1 G22 L6-11, unfixed in README.
**Suggested fix:** Append ", mode fields".

### [P2] `edm-init` usage/help string omits two valid `--mode` values — bin/edm-init:3,26
**Evidence:** Usage (`:3`) and the `die` usage (`:26`) advertise `--mode standard|mini-srd|prototype`, but the validator (`:30-33`) accepts five (`standard|mini-srd|iac|data-ml|prototype`).
**Suggested fix:** Update lines 3 and 26 to list all five.

## Round-1 fix verification (L6)

**G16 (doc-accuracy batch) — PARTIAL:** item 1 (README product-scoped tree) FIXED; item 2 (README `code-audit/` dir) REGRESSED/UNFIXED (finding); item 3 (TaskCompleted claim) FIXED; item 4 (dead link) FIXED; item 5 (CLAUDE.md subcommand list) FIXED (all 36); item 6 (userConfig keys) FIXED (all 19); item 7 (PreToolUse lint hook docs) FIXED; item 8 (test-coverage-auditor disallowedTools) PARTIAL (agent fixed, CLAUDE.md:271 not — finding).

**G22 (doc nits) — PARTIAL:** L6-09 (test-contract GraphQL) PARTIAL (tables fixed, frontmatter not — finding); L6-10 ("Verified May 2026") NOT FIXED but DEMOTED to NOTED; L6-11 (README mode-fields) NOT FIXED (finding); L6-12 (archive convergence gate docs) FIXED; L7-04 (audit-logic severity one-liner) NOT FIXED (L7 territory); L7-05 (test-coverage-auditor disallowedTools placement) FIXED.

**Rewrite-specific message/comment accuracy (new this pass) — all ACCURATE except findings above:** lock-failure messages (`:350`,`:360`), path-traversal rejection (`:145`), `n/a` savings (`:975/:986/:913`), `Phase N` label (`:974`), G3 checkpoint comment (`:669`), `list_state_files` comment (`:50-52`), atomic-write comments (`:291-296`,`:308-327`), CHANGELOG 2.0.0 entry — all match the code.

## Noted / Not Actionable

- README.md:132 prose `SRD/{PREFIX}/.edm-state.json` — deliberate shorthand; the README tree shows the canonical path. NOTED.
- CLAUDE.md:225 / edm-state:227 "Verified May 2026" — constants correct, only the month label ~1 month stale; below P2. NOTED.
- edm-state:1116-1120 migrate-path comment "via the typed path" — slightly loose, but a code/L3 concern (locking), not an operator-facing doc error. NOTED.
- `.bak`/`.lock` gitignore — L5's lens, not a doc-accuracy finding. NOTED.
- edm-audit-logic.md:55 "+ NOTED" omission — cosmetic, primarily L7. Recorded in G22 verification.
