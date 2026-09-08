# Explorer addendum 04 -- CA-114 measured at runtime

**Author**: orchestrator, not an `edm-explorer` agent.
**Why**: explorer 01 was asked to demonstrate CA-114's timing and could not -- `edm-explorer`'s
tool grant has no `Bash` (`agents/edm-explorer.md`: Glob, Grep, LS, Read, NotebookRead, WebFetch,
TodoWrite, WebSearch, KillShell, BashOutput, Write). That was a briefing error on my part: I asked
for a measurement the agent type structurally cannot take. It flagged the gap rather than guessing,
which is the correct behaviour and the reason this addendum exists.

## What CA-114 claims

`regex_match` runs an untrusted Oniguruma pattern with no time bound; the 64 KiB input cap bounds
SIZE, not TIME, so a catastrophic-backtracking pattern in a committed rule file is a denial of
service on the developer's own session.

Explorer 01 confirmed the **analytical** half against the code: the cap is input-length only,
uniform across all six operators, and there is no pattern-complexity check and no wall-clock bound
anywhere on the `jq` invocation. That is all true.

## What measurement shows

Host: `jq-1.8.1`. **Neither `timeout` nor `gtimeout` is on PATH**, so the obvious wall-clock fix is
genuinely unavailable, exactly as the finding anticipated.

Timings, classic catastrophic patterns, wall clock in ms (jq process startup is ~40 ms of each):

| input length | `(a+)+$` | `^(a\|a?)+$` |
|---|---|---|
| 100 | 139 | 120 |
| 1,000 | 144 | 129 |
| 10,000 | 147 | 140 |

**Flat across a 100x input increase.** A genuinely unbounded backtracking engine would go from
milliseconds to minutes over that range. It does not.

The mechanism is Oniguruma's own retry limit. Driven at the shape that triggers it -- 40 `a`
characters followed by a non-matching `X`, against `(a+)+$` -- `jq` does not hang; it errors:

```
jq: error (at <unknown>): Regex failure: retry-limit-in-match over
```

## End-to-end behaviour, through the real consumer

A rule file carrying `"pattern": "(a+)+$"`, plus a second benign `warn` rule alongside it, evaluated
through `bin/edm-bash-gate`:

```
edm-hookify: setup error: .../catastrophic.json: rule evaluation error: Regex failure: retry-limit-in-match over
benign-warn warn benign rule fired
exit=0
```

Four properties hold simultaneously:

1. **Bounded.** The retry limit converts catastrophic backtracking into an error, not a hang.
2. **Attributed.** The offending rule FILE is named, so an author can find it.
3. **Isolated.** The benign rule alongside it still fired -- CA-030's per-file try/catch is working.
4. **Non-blocking.** Exit 0. A catastrophic pattern degrades to a setup error, which the two-tier
   contract says never blocks.

## What this does to the decision

**CA-114's premise is true and its conclusion does not hold on this build.** There is no
EDM-authored time bound, and the 64 KiB cap really does only bound size -- but Oniguruma supplies a
bound of its own, and every layer above it behaves correctly when that bound trips. The
denial-of-service outcome the finding describes does not reproduce.

The decision therefore changes shape. It is no longer "how do we bound an unbounded regex". It is:

**Do we depend on Oniguruma's retry limit deliberately, or defensively?**

- **Option 1 -- depend on it, and say so.** Document that the bound is the regex engine's, not
  EDM's, and add an assertion pinning the observed behaviour (a known-catastrophic pattern must
  produce a setup error and must not block). Cost: near zero. Risk: a future `jq` or Oniguruma that
  raises or removes the limit reintroduces the exposure silently, and the assertion is what would
  catch it.
- **Option 2 -- add an EDM-side bound anyway.** No `timeout` binary exists, so this means a
  pattern-complexity heuristic (reject nested quantifiers) or a subprocess watchdog. Cost:
  meaningful complexity in a hook whose marker-absent fast path is budgeted at one exec. Risk: a
  complexity heuristic rejects legitimate patterns, which is a worse failure than the one it
  prevents.
- **Option 3 -- drop `regex_match` from the operator set.** Removes the class entirely. Cost: the
  most expressive operator, and a documented feature, both gone.

**Residual either way, stated for the gate**: the bound is a default of a dependency EDM does not
pin. `CLAUDE.md`'s required-binary contract names `jq` without a version floor.

## Not established

- Whether a pattern exists that defeats Oniguruma's retry limit on this build. Three classic
  catastrophic shapes were tried at input lengths to 10,000; absence of a counterexample is not
  proof of its impossibility.
- Whether the retry limit is configurable per-invocation from `jq`. Not investigated.
