# Lens L8: Security & Portability -- Round 4

Scope: `plugins/edm/` (bin/, bin/tests/, evals/, hooks/, docs/) plus `.gitlab-ci.yml`.

> **Harness note**: this agent's output contained instruction-shaped text flagged by the host as
> a possible prompt-injection pattern (bypass-permissions-related phrasing). Reviewed: the flagged
> text is the agent's own finding narration (quoting `bypassPermissions` while explaining why the
> eval driver's comment discusses and avoids it), not an actual embedded instruction to this
> session. Relayed as a normal finding below (L8, Noted item on CA-086); no action taken on any
> directive-shaped text.

## Verification of open L8 ledger entries

| Ledger ID | Sev | Verdict | Evidence |
|---|---|---|---|
| CA-186 | P1 | **PARTIALLY FIXED** -- three named defects closed, fail-open class survives in two shapes | see L8-002, L8-003 |
| CA-215 | P2 | **FIXED** | proof path derives from suite's trap-covered `$TMP`, pre-cleaned before probe |
| CA-232 | P2 | **FIXED** | `_harness.sh:75-76` uses non-local var + single-quoted trap body, deferring expansion |
| CA-233 | P2 | **NOT FIXED** -- all three halves still open | see L8-005 |
| CA-234 | P2 | **FIXED**, better than prescribed | blocking-job set derived from `.gitlab-ci.yml` itself, resolves to 11 jobs |
| CA-235 | P2 | **FIXED** | two new check_fails cases probe CA-157's guard on both entry points |

### CA-186: full data-flow trace

Genuinely closed: looped trailing-slash strip, absolute-value refusal, `ENVIRON[]` pass instead
of `awk -v`, and a real end-to-end positive control at `wave7-smoke.sh:5369-5436`.

Surviving bypass shapes: L8-002, L8-003.

## Findings (L8: Security & Portability)

| ID | File:Line | Vulnerability Class | Fix |
|----|-----------|----------------------|-----|
| L8-001 | `hooks/hooks.json:19` (also `:32`,`:45`,`:58`,`:71`) | All five UserPromptExpansion gate hooks refuse with `exit 1`, which Claude Code treats as non-blocking and proceeds anyway. Only exit 2 blocks. The deterministic half of HITL gate enforcement does not enforce. | Change both `exit 1` sites to `exit 2` in all five hooks; drop `2>&1` from the gate-check invocation. |
| L8-002 | `hooks/hooks.json:86` | CA-186 residual: an absolute `srd_root` still disables all commit-time enforcement, and the diagnostic is written to stderr on an exit-0 path, which Claude Code sends to the debug log only -- never the transcript. | Relativize an absolute value under the repo when possible; for genuine failures use exit 1 (shown in transcript) not exit 0. |
| L8-003 | `hooks/hooks.json:86` | CA-186 residual: only one leading `./` is stripped and the trailing-slash collapse runs before the absolute check, so `././SRD`, `SRD/.`, and `/` still fail open with no message on any channel. | Loop the `./` strip; move the absolute check ahead of the trailing-slash collapse; add a `test -d` positive control. |
| L8-004 | `bin/edm-state:3381` | NEW: git-lock-check's `pgrep -f -- "$git_dir"` interpolates an unescaped ERE; at repo root `git_dir` is literal `.git`, which self-matches the checking process's own ancestry, making the removal branch unreachable; an invalid-ERE `GIT_DIR` empties the evidence and removes the lock with no liveness check at all. | Normalize to absolute path, match as fixed string, exclude own process tree. |
| L8-005 | `.gitlab-ci.yml:105-107` and `:216` | CA-233 unfixed: `lint:bash-syntax` excludes only `*.awk`; `lint:shellcheck` has no extension filter at all, so both vocabulary `.txt` files are parsed as bash/shellcheck by two blocking linters; a load-bearing line-ordering comment in `vocabulary-allowlist.txt:41-44` survives as a result. | Add a `*.txt` exclusion to both loops; delete the prose constraint from the data file. |
| L8-006 | `bin/tests/wave7-smoke.sh:4203` (identical copy at `:4226`) | CA-234 residual: the job-body extractor's terminator regex admits a column-0 comment line ending in a colon, which would silently truncate a job body and hide a later network call from the scan. | Change the regex to `/^[^[:space:]#][^#]*:$/`. |

## Noted / Not Actionable

1. CA-123 re-swept at full scope -- flock remains on fd 200, no fd 9/10-19 use anywhere.
2. CA-086 verified closed as filed -- comment accurately describes the prefix-matcher escape and
   why `bypassPermissions` is deliberately avoided; posture is a documented deliberate tradeoff.
3. CA-124 unchanged -- `git add -A` operates only on the scratch fixture copy.
4. CA-111 unchanged -- placeholder digests and floating tag are self-declared with a refresh procedure.
5. `CLAUDE.md:365,:373` absolute developer-machine paths are a licence-provenance attestation, not a runtime path.
6. Bare `mktemp -d` with no template honors TMPDIR on both GNU and BSD -- not the CA-014 class.
7. `edm-state:604`'s CA-232 exemplar citation off by three lines -- cosmetic, L6/L10 territory.
8. `wave7-smoke.sh:4164-4165`'s CA-023 comment is now itself the inverted one after Wave 7 fixed
   the note it references -- doc-only, L6 territory.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L8.md` and `lens-L8.jsonl` were transcribed by the orchestrator.
