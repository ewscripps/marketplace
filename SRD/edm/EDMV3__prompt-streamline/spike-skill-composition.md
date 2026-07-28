# Spike: Skill-Tool Composition Depth (EDMV3-T34)

**Date**: 2026-07-28
**Time-box**: ~20 minutes (target 10-30 minutes, AC1)
**Method**: A scratch plugin (`spike` -- three skills: `spike-caller`, `spike-mid`, `spike-leaf`,
never committed to this repository) was loaded into a real, unmodified Claude Code binary via
`claude --plugin-dir <scratch-dir>` and driven headlessly:

```bash
claude --plugin-dir <scratch-dir> -p "/spike:spike-caller depth-test-token" --permission-mode acceptEdits
```

`spike-caller` invokes `spike-mid` via the Skill tool; `spike-mid` invokes `spike-leaf` via the
Skill tool (a two-level chain, AC2) and additionally probes a nonexistent target skill (AC3). Each
skill wrote its observations to plain files under `/tmp/edm-spike-results/` so the result is a
file on disk, not a claim about a transcript. This is the real Claude Code runtime resolving an
installed plugin cache (an ad hoc `--plugin-dir` load), matching the precedent EDMV3-T41 sets for
"the runtime resolution behaviour is what matters" -- not the development tree's static text.

## Question 1: Does the invocation succeed?

**Yes.** `spike-caller` invoked `spike-mid` via the Skill tool; `spike-mid` invoked `spike-leaf`
the same way. All three skills ran to completion and every expected output file was written with
no tool errors on the successful calls. Raw evidence:

- `/tmp/edm-spike-results/caller-start.txt`: `CALLER_SAW_ARGS=depth-test-token`
- `/tmp/edm-spike-results/mid-start.txt`: `MID_SAW_ARGS=depth-test-token-via-caller`
- `/tmp/edm-spike-results/leaf-final.txt` line 1: `LEAF_SAW_ARGS=depth-test-token-via-caller-via-mid`

## Question 2: Does `$ARGUMENTS` reach the callee?

**Yes, and it composes across hops.** The caller received `depth-test-token`, appended
`-via-caller` and passed `depth-test-token-via-caller` to `spike-mid` as its `args:` string;
`spike-mid` read that value as its own `$ARGUMENTS` (confirmed by `mid-start.txt`), then appended
`-via-mid` and passed the composed string to `spike-leaf`, which read the full
`depth-test-token-via-caller-via-mid` as its own `$ARGUMENTS` (confirmed by `leaf-final.txt`).
`$ARGUMENTS` is passed explicitly as the `args:` string on each Skill-tool call -- it is not
inherited implicitly, but a caller that forwards or composes it (as every phase skill in this
epic already plans to) sees it arrive intact at the callee, at depth 2.

## Question 3: Are variables set by the caller visible to the callee?

**Yes -- the callee runs in the same conversation, not an isolated sub-agent context.**
`spike-caller` silently noted a secret word (`BANANA-42`) in step 1 without ever writing it to any
file or passing it as an argument. Both `spike-mid` (one hop away) and `spike-leaf` (two hops
away) correctly recalled and reported it:

- `/tmp/edm-spike-results/mid-secret-check.txt`: `MID_SEES_CALLER_SECRET=yes, the word is BANANA-42`
- `/tmp/edm-spike-results/leaf-final.txt` line 2: `LEAF_SEES_ORIGINAL_SECRET=yes, the word is BANANA-42`

This is the key mechanism finding: Skill-tool composition runs the callee's instructions **within
the same conversational context** as the caller, rather than spawning an isolated sub-agent (the
way the `Task` tool does for `edm-explorer`, `edm-implementer`, etc.). Context accumulated by the
caller is visible to the callee automatically, without needing to be threaded through as an
explicit argument.

## Question 4: Whose `allowed-tools` govern?

**Each skill's own `allowed-tools` governs its own actions -- grants are not intersected with, or
limited by, the caller's.** `spike-caller`'s `allowed-tools` is `Read, Write, Skill` (no `Bash` at
all). `spike-mid`'s `allowed-tools` includes `Bash`. When `spike-mid` ran a `Bash` command
(`date -u`) after being invoked by the Bash-less `spike-caller`, it succeeded:

- `/tmp/edm-spike-results/mid-bash-check.txt`:
  ```
  MID_BASH_RAN=yes
  Tue Jul 28 05:57:37 UTC 2026
  ```

This confirms the **caller obligation** this ticket's AC6 requires documenting: a caller does not
need the callee's tools in its own `allowed-tools` (nor vice versa) -- each skill's frontmatter is
the authority for what that skill, while executing, may do. The only obligation on the caller is
holding `Skill` itself, to be able to place the call at all.

## Question 5: What happens when the target skill is not enabled?

**A single, catchable tool-use error naming the skill.** `spike-mid` attempted
`skill: "spike-ghost-does-not-exist", args: "x"` (a name that exists nowhere in the loaded plugin
set, the closest available proxy for "not enabled" in a single-plugin scratch load). The Skill
tool call itself failed with a structured error rather than silently no-op'ing or hanging:

- `/tmp/edm-spike-results/mid-disabled-target.txt`:
  `DISABLED_TARGET_OUTCOME=tool_use_error: Unknown skill: spike-ghost-does-not-exist`

`spike-mid` observed this error and continued -- the calling skill's own turn did not crash, it
received the error back and could act on it (in this spike, simply recording it; a production
caller would report the unavailable skill by name and stop, per this ticket's AC8 requirement for
`CLAUDE.md`'s rewritten rule). This is precise enough to write the graceful-degradation
instruction EDMV3-50 requires: **on a Skill-tool error, name the unavailable skill in the error
text and stop -- do not silently continue, and do not fall back to inlining the target's
procedure.**

## Question 6: Does context accumulated in the caller survive the round trip?

**Yes.** After `spike-mid` (and, through it, `spike-leaf`) returned control to `spike-caller`,
the caller could still recall its own pre-call secret word and could see that the callee had run:

- `/tmp/edm-spike-results/caller-final.txt`:
  ```
  SECRET_STILL_KNOWN=yes
  MID_RESULT_VISIBLE=yes
  ```

## AC2: Depth, not just existence

The spike exercised a two-level chain in one session: `spike-caller` -> `spike-mid` ->
`spike-leaf`. Both hops succeeded, `$ARGUMENTS` composed correctly across both, and context
(the secret word) was visible at both hops, not just the first. This directly answers the
depth risk WS5 raises for a dispatcher chaining `orchestrator -> phase skill` up to six times
across a full initiative: the mechanism does not appear to degrade between hop 1 and hop 2.

## Recommendation: GO

**GO.** Every question above resolved cleanly and in the direction the R4/D10 dispatcher design
assumes: invocation succeeds, arguments propagate and compose, context survives (because the
callee runs in the same conversation rather than an isolated sub-agent), each skill's own grants
govern its own actions, depth-2 chaining works, and a missing target fails with a clean, nameable
error rather than a silent hang. This matches the git plugin's existing production precedent
(`/commit` invoking `search-jira` via the Skill tool, documented in root `CLAUDE.md`'s
"Cross-Plugin Skill Invocation" section) and gives it a second, independent, depth-2 confirmation.

Recorded as decision D21 in `decisions.md`. Per this ticket's AC4, no rescope of EDMV3-T35 through
EDMV3-T38 is triggered -- they proceed as planned.
