# EDM v2 -> v3: what changed, why

**Original purpose:** v2 had gates and rules written in prose ("the model should ask for approval,"
"nothing should be deferred") but nothing actually enforced them. An outside review plus this
initiative's own explorers found the plugin could bypass its own gates in 3 commands, had broken
Mermaid diagrams, tracked zero cost data, and measured nothing. v3's job: turn "the methodology
says X" into "the code refuses if not X."

**1. Gates became unbypassable, not just requested.** Approving a phase or archiving an initiative
now requires an actual human permission click (`.claude/settings.json` `ask` rule), not just the
model saying "please approve." The 3-command bypass that used to work (`edm-init` -> flip a flag ->
`archive`) no longer does.

**2. Findings tracking became structured data, not prose.** Code-audit findings used to be
freeform text a human re-read to decide "are we done?" Now every finding is a JSON line with a
stable ID and confidence score, and "converged" is a computed database query -- not a judgment
call that can silently drift from reality.

**3. Nothing can be silently skipped -- but there is one sanctioned, human-approved exception.**
Default policy: every finding at every severity gets fixed before done, and every "we'll verify
that later" (PARTIAL) item must be actually verified before an initiative is archived. The
vocabulary for deferring is banned outright and checked by a script. The one sanctioned exception:
once every P0 (critical) and P1 (significant) finding is closed, a human can explicitly choose to
converge with the remaining low-priority P2 polish items carried forward as documented debt --
never silent, never automatic, and never available while any P0/P1 is still open. It also can't be
used to skip an unfinished documentation sweep on something already marked fixed. The choice, who
made it, and the exact count of debt carried are all recorded in the initiative's state file, so a
teammate always sees debt was knowingly accepted, not silently missed.

**4. The orchestrator shrank from 645 lines to ~200.** It used to contain all 6 phases' full
instructions inline, duplicated across files that drifted out of sync. Now it's a thin dispatcher
that hands off to one dedicated file per phase -- each phase's instructions live in exactly one
place.

**5. Mermaid diagrams stopped randomly breaking.** A literal semicolon in a diagram label was
silently corrupting charts. Fixed with one canonical rule, applied everywhere diagrams get written
or checked.

**6. Cost tracking became real.** Phase 6 (implementation) used to always show $0.00 spent
regardless of actual usage -- the code path that should have recorded it was never called. Fixed,
plus the pricing table was updated to current model rates and cost attribution no longer
double-counts across sessions.

**7. Tool grant mistakes got fixed and locked down.** Agents were being told to write files they
had no permission to write. Fixed for all 13 affected agents, plus a permanent automated check so
this class of bug can't recur silently.

**8. Housekeeping.** Deleted ~700KB of stray binary files (a PowerPoint, a Word doc) that were
shipping inside the plugin, a dead no-op hook, and an unused config value.

**9. Lower cost on lenses that don't need judgment.** The 11 code-audit lenses all ran on the most
expensive model/effort tier regardless of how much judgment each needed. Mechanical ones were
moved to a cheaper tier.
