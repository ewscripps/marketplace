# Key Decisions

| # | Decision | Chosen | Rationale | Date |
|---|----------|--------|-----------|------|

## Finding-to-Commit Ledger

| Finding | Source | Decision | Ticket | Status |
|---------|--------|----------|--------|--------|

## Key Decisions

| Decision | Question | Choice | Rationale | Date |
|---|---|---|---|---|
| Gate 1 | Is EDMDS's scope, constraint set and go/no-go sound enough to enter the fused SRD? | **Approve, on a standing instruction rather than a gate-time selection** | `planning.md` returns GO with three scope adjustments, all evidence-backed: CA-114 descoped from "add a bound" to "decide whether to depend on one" (its premise is disproved by measurement -- Oniguruma's retry limit bounds it, the error is attributed to the rule file, sibling rules still fire, exit code 0); CA-109 reclassified UP into Epic 1's severity class (two of three project-root resolvers accept `CLAUDE_PROJECT_DIR` unchecked, and `edm-hookify`'s own comment claiming parity is false); CA-072 reduced from five copies to three, byte-identical. The three-epic split held under direct code reading. Two constraints are recorded because they bind implementation: `run-all.sh` at or above 4048/0, and one line of headroom on `bin/edm-gateguard` against `EDMV4-T11` AC1's closed 200-660 bound | **Recorded this way because the approval basis is not a gate-time selection, and writing that down is the point.** The user instructed "go until completion" and then "continue with mini srd". Gate 1's substance -- scope, the three reclassifications, the constraint set, the go/no-go -- was reported to them in full before this was recorded, so the human was informed rather than bypassed, which is what `Gate PROTOCOL` exists to protect. **Gate 2+3 is deliberately NOT being handled this way.** That gate ratifies eighteen design decisions the user has not yet seen, and creating exactly one such checkpoint is the entire reason `mode=mini-srd` was chosen over `fix-pack`. Approving it by inference would discard the only structural benefit of the mode choice | 2026-09-08 |
