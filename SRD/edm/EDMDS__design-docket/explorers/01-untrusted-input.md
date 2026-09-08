Epic 1 exploration -- CA-113, CA-114, CA-116, CA-122, CA-063

Scope: `plugins/edm/bin/edm-gateguard`, `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/edm-bash-gate`,
`plugins/edm/bin/edm-stop-gate`, `plugins/edm/hooks/hooks.json`, `plugins/edm/CLAUDE.md`,
`plugins/edm/README.md`, and the tickets/decisions.md this behaviour was authorized against.

**Toolset note up front**: this explorer's own grant is Read/Glob/Grep/Write/WebFetch/WebSearch/
TaskStop -- no Bash, no Edit, no MultiEdit. Everywhere below that would normally be settled by
running a command, I read code and prior-recorded evidence instead and say so explicitly. Two
things this docket asked me to *try to demonstrate* (CA-114's timing, `timeout`/`gtimeout`
availability) I could not execute at all -- flagged in CA-114 below, not glossed over.

---

## CA-114 -- unbounded `regex_match`, no time bound

### What I established from code

`plugins/edm/bin/edm-hookify:335`, inside the single `jq` program every `eval` call builds:

```
def op_match($op; $val; $pattern):
  if $op == "contains" then ($val|contains($pattern))
  ...
  elif $op == "regex_match" then ($val|test($pattern))
  else false end;
```

`test($pattern)` is jq's binding to Oniguruma. The `$val` fed to `test()` is capped, but the cap is
on **input length**, not on pattern complexity, and it is not `regex_match`-specific -- `cap($s)`
(`:279`) truncates to `$maxchars` (65536, set at `:200` `HOOKIFY_MAX_FIELD_CHARS=65536`) and is
applied identically to every operator's value in `conds_match` (`:348`,
`($rawval | tostring | cap(.)) as $val`). There is no separate, smaller cap for `regex_match`, no
static check on the *pattern* string (`validate()`, `:286-328`, only checks types and enum
membership -- never pattern shape), and no per-call wall-clock bound anywhere: the entire
`build_rule_stream | jq ...` pipeline (`:396-402`) is one unguarded, un-timed command substitution.
If that `jq` process hangs, the calling script hangs with it, synchronously, inside whichever
consumer invoked `edm-hookify eval`.

**The header's own claim is present and is the claim the finding disputes.** `:29-37`:

> "Bounding the INPUT bounds the cost of Oniguruma's regex_match (jq's test()) regardless of how
> large a single edit's new_text/content/command field is."

This is analytically false for catastrophic backtracking: cost for a pathological
alternation-of-repetition pattern (canonically `^(a+)+$` or `(a|aa)+$`-shaped patterns) is
exponential in the **matched prefix length**, not linear in the capped field length -- an attacker
does not need anywhere close to 64 KiB to trigger it; a few dozen characters is the textbook
demonstration size for this exact pattern shape. Bounding the field to 64 KiB bounds the *maximum*
possible blow-up, but does nothing to stop a short, cheap-looking string from already taking
seconds-to-minutes. I did not find any comment or code path in `edm-hookify` that disputes this --
the header text is the only place the claim is made, and nothing in `validate()` or `op_match()`
implements a different, cost-based bound.

**No `timeout(1)` wrapper exists anywhere in `bin/`.** `grep -r timeout plugins/edm/bin` matches
only comments (this same header, and mentions of the word "timeout" inside unrelated test-fixture
directory names under `bin/tests/fixtures/code-audit/na-l13-*` which are a naming coincidence with
L13's "N/A" test cases, not related code). The header itself (`:32-34`) states the reasoning: "
`timeout(1)` is a GNU coreutils binary absent from stock macOS, this plugin's primary development
platform" -- and `plugins/edm/CLAUDE.md` states the plugin's required-binary contract is exactly
`bash`, `jq`, `git`, nothing else (`CLAUDE.md:983`, "This plugin's required binaries are `bash`,
`jq`, and `git`"). So even where `timeout`/`gtimeout` happen to exist on a given contributor's
machine (e.g. via Homebrew coreutils, which ships `gtimeout`), depending on either would itself be
a policy violation unless done the way this codebase already has one precedent for handling an
optional, non-required binary: `bin/tests/timing.sh:56-78` probes `command -v perl` at runtime and
falls back to a working (if coarser) alternative on the same code path when it's absent, never
hard-requiring it. `EDMV4-T50` AC9 (`tickets/epics/08-cross-cutting.md:90-94`) names this exact
`timing.sh` shape as the sanctioned pattern for "a genuine platform deviation": "a runtime
`command -v` probe with a working fallback on the same code path." This is a real precedent already
in the tree for one of CA-114's fix options (a `sleep`-plus-`kill` sentinel subshell can be built
the same way, entirely in bash 3.2, with no new required binary).

**I could not execute `command -v timeout` / `command -v gtimeout` on this host, and I could not
run `jq -r 'test("^(a+)+$")'` against a crafted string to measure timing.** Both were explicitly
asked for in this docket and both require a shell, which this agent does not have. This is a real
gap, not a shrug: the demonstration is cheap and fast for anyone holding a Bash tool to run (three
commands: `command -v timeout`, `command -v gtimeout`, and a timed `jq` invocation against a string
of ~30-40 `a` characters plus one non-matching trailing character through pattern `^(a+)+$`), and I
recommend it be run before Gate 2+3 rather than assumed from the header comment's own (already
disputed) claim about portability.

### Blast radius, established from code

- **Which events can carry an author-supplied `regex_match` pattern**: `file` and `bash` only.
  `stop` defines zero matchable fields (`fields_for_event`, `edm-hookify:275-278`, returns `[]` for
  anything other than `file`/`bash`), and `validate()` rejects any condition naming a field outside
  the event's allowed set (`:321-324`) -- so a `stop`-event rule's `conditions` array must be empty
  to pass validation at all, meaning `regex_match` (or any operator) is unreachable on the `stop`
  event. This narrows the exposed surface to two of the three events, not three.
- **`file`-event blast radius**: `edm-gateguard:646-647` calls `edm-hookify eval file` via a
  synchronous command substitution (`GG_HOOKIFY_OUT="$(... | edm-hookify eval file)"`) inside a
  `PreToolUse Edit|Write|MultiEdit` hook. A hang here stalls that one tool call's hook -- i.e. the
  single Edit/Write/MultiEdit invocation the model is waiting on -- not automatically "the whole
  session," though depending on how the host client behaves on a stuck synchronous hook (no timeout
  value is set for this hook in `hooks/hooks.json:80-89`; no `timeout` key appears anywhere in that
  file at all -- confirmed by grep), it could read as the session being stuck from the user's
  perspective. **I could not establish what host-level default timeout, if any, Claude Code applies
  to an unspecified-timeout hook command** -- nothing in this repo's own docs states a number, and
  I have no way to query the host. This is worth settling before deciding how bad "one call hangs"
  actually is.
- **`bash`-event blast radius**: `edm-bash-gate:131` calls `edm-hookify eval bash` the same way,
  synchronously, inside a `PreToolUse Bash` hook that (per `hooks/hooks.json:90-96`) fires on
  **every** Bash tool call in the session -- confirmed the widest-blast-radius rule this format can
  express, matching `CLAUDE.md`'s own statement to that effect under "Hookify rule format
  (canonical)".
- **Reachability outside Phase 6**: `bash`-event rules are NOT Phase-6-scoped (`edm-bash-gate` has
  no marker check at all -- see CA-122 below for the contrast with `file`), so a committed
  `block`-action `bash` rule with a pathological `regex_match` pattern is live in every session on
  every repository that has adopted the rule file, regardless of whether any EDM initiative is
  active. This is the more dangerous of the two live surfaces, both because it is unconditionally
  reachable and because it sees every Bash call, not just edits.

### Open decision

**Given `regex_match`'s cost is exponential in matched-prefix length, not bounded by the existing
64 KiB field cap, and no `timeout(1)`-class mechanism exists in the required-binary set -- how
should Epic 1 bound it?** Real options and their costs, none of them free:

1. **Static pattern rejection at validate time** (reject nested-quantifier shapes like
   `(x+)+`, `(x*)*`, `(x+)*` before a rule is ever enabled). Cheap to add to `validate()`. Cost:
   a denylist of "dangerous" regex shapes is a known-incomplete mitigation class -- Oniguruma has
   other pathological shapes a simple syntactic check will not catch, so this reduces but does not
   eliminate the exposure, and it changes the rule format's contract (a previously-valid pattern
   can become a setup error).
2. **A `sleep`-plus-`kill` sentinel subshell around the `jq` invocation**, bash-3.2-compatible, no
   new required binary -- the shape `EDMV4-T50` AC9 already sanctions for `timing.sh`'s optional
   `perl` probe, adapted here to a hard kill rather than a fallback. Cost: this is a real amount of
   new bash plumbing (background the `jq` classify pass, poll or `wait` with a timeout, `kill` on
   expiry, and correctly propagate "the regex hung" as the documented setup-error exit 1, never a
   block) inside a script whose whole design point (the header's own words) was "one process exec,
   ... no parser subprocess" on the fast path -- this only touches the gated path, but it adds
   asynchronous-process-management complexity to a file that has so far been synchronous
   throughout, and every hook-consumer family member (`edm-gateguard`, `edm-bash-gate`,
   `edm-stop-gate`) needs the same treatment or the fix is partial.
3. **Lower the field cap substantially for `regex_match` specifically** (e.g. a few hundred
   characters instead of 64 KiB). Cost: this does not fix the core problem -- a short string is
   already enough to hang, as noted above -- so this option alone is close to cosmetic; it would
   need to be paired with (1) or (2) to matter.
4. **Do nothing beyond correcting the false header claim.** Cheapest option. Cost: leaves a
   source-controlled file (a rule an operator did not necessarily author themselves, if the project
   adopts rules from a shared template or a less-trusted contributor) able to hang a blocking hook
   on every Bash call in every session, with no kill switch that helps once the hang has already
   started (`EDM_HOOKIFY`/`EDM_HOOKIFY_DISABLED` are checked before rule evaluation, so they prevent
   a *future* hang but do not un-stick a session already inside one).

None of these can be validated against a measured number from this exploration -- the timing
demonstration and the `timeout`/`gtimeout` availability check are both outstanding, per above.

---

## CA-113 -- rule `message` reaches `permissionDecisionReason` with no provenance frame

### What I established

`plugins/edm/bin/edm-gateguard:646-651` (current line numbers; REMEDIATION's `:405` citation has
drifted with intervening edits but is the same code):

```bash
GG_HOOKIFY_OUT="$(printf '%s' "$GG_HOOKIFY_PAYLOAD" | edm-hookify eval file)" || GG_HOOKIFY_RC=$?
...
[[ "$GG_HOOKIFY_RC" -eq 2 ]] && emit_decision deny "$GG_HOOKIFY_OUT"
```

`$GG_HOOKIFY_OUT` is exactly `edm-hookify`'s own stdout for a matched block rule --
`hookify_emit_match` (`edm-hookify:414-425`) prints `"<rule_id> <action> <message>"`, where
`<message>` is the rule author's own `message` field, read verbatim from a working-tree JSON file
at `.claude/edm-hookify/*.json` and passed through no filter beyond ASCII-safety (see below). That
whole line becomes the `$reason` argument to `emit_decision` (`edm-gateguard:199-247`), which does:

```bash
reason="$(printf '%s' "$reason" | LC_ALL=C tr -c '\011\012\015\040-\176' '?')"
...
jq -cn --arg reason "$reason" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
```

There is no label, prefix, or structural marker anywhere in this path distinguishing rule-authored
text from EDM's own four-fact denial text (`gg_build_facts`, `:543-558`) -- both travel through the
exact same `emit_decision deny` call and land in the exact same `permissionDecisionReason` string
key the host hands back to the model as the authoritative refusal reason. To the model, a
`file`-event rule's `message` is indistinguishable in form from EDM's own facts.

**Three sanitization passes exist on this path, and none of them is a provenance frame -- all three
are byte-safety filters only:**
1. `edm-hookify`'s internal jq-level `scrub` (`:285`, `def scrub($s): ... if . < 32 or . == 127 then
   32 else . end`) -- replaces control characters with spaces, purely to stop a crafted rule
   `name`/`message`/error-reason from desynchronizing the tab-delimited record stream the bash side
   parses (this is CA-029's fix, documented in the file's own header at `:42-56`).
2. `hookify_scrub` (`edm-hookify:225-227`) -- an ASCII-range filter (`tr -c '\011\012\015\040-\176'
   '?'`) applied to the `<rule_id> <action> <message>` line before it is printed to stdout/stderr.
3. `emit_decision`'s own identical `tr -c` pass (`edm-gateguard:213`), applied again as
   defense-in-depth before the `jq -cn --arg` call, with the comment at `:202-212` explicitly
   naming its purpose: protecting the JSON control channel from a raw non-ASCII byte, nothing about
   labeling the text's origin.

I confirm the docket's premise directly: `CLAUDE.md`'s own "Artifact content conventions" section
(which documents CA-029's `scrub` and the ASCII rule generally) never claims to address trust
labeling, only byte encoding -- there is no provenance-framing mechanism anywhere in this codebase
for hookify-sourced text.

**The same channel exists at the other two consumers, with differing (but still absent)
provenance treatment**, worth noting as context for a single fix:
- `edm-bash-gate:136`: `printf '%s\n' "$HOOKIFY_OUT" >&2` on a block -- no label at all precedes the
  raw `<rule_id> block <message>` line.
- `edm-stop-gate:216,244`: routes through `stop_gate_emit_blocking` (`:120-124`), which DOES prefix
  a literal label -- `"[EDM] a stop-event hookify rule matched:"` -- before the raw text. This is
  the only one of the three consumers that names the text's origin at all, and even this is a bare
  descriptive label, not a "this is untrusted, project-authored text, not an EDM-authored
  instruction" framing, and it still interpolates the message unquoted immediately after.

An operator or the model reading a `gateguard` denial sees zero distinguishing marks; reading a
`stop-gate` denial sees a one-line attribution but no explicit untrusted-content framing; reading a
`bash-gate` denial sees neither.

### Open decision

**Should a rule author's `message` reach an operator/model-facing refusal string at all, and if so,
how should it be framed?** Real options:

1. **Wrap in an explicit non-instruction frame** naming the rule id and file path and marking the
   body as untrusted project text (REMEDIATION's suggested direction) -- e.g. something structurally
   distinct from `gg_build_facts`'s numbered-fact prose, with a fixed preamble the model has been
   told elsewhere to treat as a content boundary. Cost: this is a prompt-injection-adjacent design
   problem, not just a string-formatting one -- a "frame" is only as strong as the model's
   willingness to respect it, and this plugin has no existing mechanism anywhere else for
   labeling untrusted content to the model (the four EDM-authored facts are the only precedent, and
   they are trusted-by-construction). Getting this wrong (a frame the model can be talked out of)
   is worse than no frame, because it creates a false sense of the problem being solved.
2. **Cap the interpolated length** in addition to (1) -- reduces the size of an injected payload but
   does not address the trust-labeling gap on its own.
3. **Do not interpolate rule `message` into the operator-facing refusal at all** -- log it
   separately (stderr, a file) and put only a fixed, EDM-authored sentence ("a project rule
   blocked this edit; see stderr / the rule file") into `permissionDecisionReason`. Cost: this is
   the most conservative option and closes the channel outright, but it also removes the
   customization value the whole hookify format exists to provide -- a rule author's `message` is
   the entire point of the `message` field, and this option makes it invisible to the one channel
   (the model's own refusal-reason text) most likely to actually change model behavior on retry.
4. **Leave it as-is and accept the risk**, documenting it as a known, accepted trust boundary (a
   project that commits a hostile rule file has already compromised its own supply chain in a way
   this format cannot fully defend against). Cost: this is honest about scope but does not close
   the "impersonate EDM's own refusal text" concern the docket raises, and CA-196 (referenced in
   REMEDIATION) already records the identical class pre-existing in `edm-lint-staged-artifacts`,
   so choosing "accept" here is choosing to leave a now-multi-site pattern unaddressed.

---

## CA-116 -- `MultiEdit` arm shipped against unmet D26 precondition

### What I established

**D26's exact text** (`SRD/.archived/edm/EDMV4__ecc-integration/decisions.md`, the D26 row),
quoted directly:

> "`EDM_GATEGUARD_DENY_MODE` defaults to `json`, evidence-backed for `Edit` and `Write`; `MultiEdit`
> is UNTESTABLE on this host, not PASS or FAIL." ... "the tool is **absent from this Claude Code
> session's toolset entirely** -- not in the loaded tool list and not reachable via the host's own
> `ToolSearch` deferred-tool lookup (`select:MultiEdit` returned "No matching deferred tools
> found"), reproduced twice: once under natural instruction and once forcing it via
> `--allowedTools MultiEdit`." ... "`MultiEdit` remains genuinely unverified and should be
> re-tested before GateGuard's `MultiEdit` arm ships against a host where the tool is confirmed
> present."

So the condition D26 states is explicit and unambiguous: re-test on a host where `MultiEdit` is
confirmed present, before shipping the arm. This did not happen. **D44** (same file, "Wave 5 / D44"
row) closes six tickets including `T07` (the spike ticket D26 belongs to) as `NOT
RUNTIME-VERIFIED`, carried to a **named follow-on initiative, `EDMRT`**, with the stated reason
being `EDMV4-62`: neither `/plugin update` nor `/reload-plugins` reads the working tree, so the
initiative building the code could never observe it running live in the same session. D44 confirms
`T07`'s AC "names `MultiEdit`, which Spike B proved absent from this host's toolset twice including
with `--allowedTools MultiEdit` forced" -- i.e. D44 treats this as a specification defect (D15
class: an AC whose runtime environment does not exist), not as a re-test that happened.

**`EDMRT` was never created.** `Glob "SRD/**/EDMRT*/**"` returns no results, and the only mentions
of the string `EDMRT` anywhere under `SRD/` are inside `EDMV4`'s own closed-initiative artifacts
(`REMEDIATION.md`, `decisions.md`, `.edm-state.json`, `qc/qc-summary.md`, `lens-L9.md`) -- all
referring to it as a planned name, none as a directory that exists. The re-test D26 asked for has
not happened in this codebase's history, on any branch this exploration can see.

**The `MultiEdit` arm shipped anyway.** `plugins/edm/hooks/hooks.json:82`:
`"matcher": "Edit|Write|MultiEdit"` -- registered, unconditionally, matching `EDMV4-T11`'s AC.
`plugins/edm/bin/edm-gateguard:604-620` implements the `MultiEdit)` case arm in the tool-name
dispatch, including the dual-shape tolerance the code comment there admits was a guess ("Tolerant
of both the SRD's assumed multi-file batch shape ... and Claude Code's own single-file shape ...
the live shape could not be confirmed from this environment").

**Whether the precondition is now satisfiable, from this session**: I cannot confirm `MultiEdit`'s
presence or absence on the *general* host either way from here. This explorer agent's own function
list (visible to me at the top of this conversation) does not include `MultiEdit`, `Edit`, or
`Bash` at all -- but that is an artifact of this being a narrowly-scoped, read-only explorer
subagent, not evidence about what tools a full orchestrator or implementer session on this same
host would be granted. It settles nothing about the general question D26 asks, and I want to be
explicit that "MultiEdit is absent from my toolset" and "MultiEdit is absent from this host" are
different claims -- I can only support the former.

### Open decision

**D26's own shipping condition is unmet and has been unmet since it was written; the question is
how to close that gap, not whether it exists.** Options:

1. **Amend D26's closing sentence** to record that the arm ships unverified under `T11`'s AC, and
   is formally carried by a real follow-on (either instantiate `EDMRT` for real, or fold the
   re-test into this docket's own scope, or another named initiative). Cost: cheap to write, but it
   is a paper reconciliation only -- it does not close the actual uncertainty about whether
   `MultiEdit` denial works, it just stops the two ledgers from contradicting each other.
2. **Actually re-test**, requiring a session where `MultiEdit` is confirmed present in the tool
   list -- which, per D26's own finding, this repository's spike could not produce even when
   forcing it via `--allowedTools MultiEdit`. Cost: this is not fully in this initiative's control;
   it depends on a host/config where the tool loads, which no evidence in this tree shows exists
   yet. Committing to this option risks becoming an indefinite blocker if `MultiEdit`'s
   unavailability is structural to how this Claude Code version dispatches multi-edit calls at all
   (a question this exploration cannot answer).
3. **Withdraw the `MultiEdit` arm** (drop it from the matcher, or special-case it to always allow)
   until it can be verified. Cost: this changes a shipped, ticket-mandated behavior
   (`EDMV4-T11`'s AC explicitly requires the `Edit|Write|MultiEdit` matcher) and would itself need
   a new decision superseding that AC -- and if `MultiEdit` genuinely never fires on this host
   class, the arm is dead code either way, so withdrawing it costs little in practice but requires
   explicitly re-opening `T11`'s AC to do honestly.

Whichever option is chosen, note the reasoning already on record in D26/D44: this is explicitly
framed there as a D15-class specification defect (an AC naming a runtime environment that does not
exist), which per `CLAUDE.md`'s own "Unverifiable acceptance criteria (D15)" section has exactly
two sanctioned responses (rework the AC, or move it out of scope as a recorded boundary) --
"leave it unresolved" is not one of the two, which is itself part of why this is now a P2 finding
rather than a closed matter.

---

## CA-122 -- `file`-event rules unreachable outside Phase 6

### What I established -- control flow

`plugins/edm/bin/edm-gateguard:100-104`:

```bash
# The allow path: the ONLY filesystem check when no initiative is in Phase 6. ...
if [[ -z "$MARKER_PATH" ]] || ! test -f "$MARKER_PATH"; then
  exit 0
fi
```

This is a bare `exit 0` -- the whole process terminates here on marker absence. The hookify call
site is far below it, at `:627-653` (comment at `:627-629`, the `command -v edm-hookify` guard at
`:630`, the actual `edm-hookify eval file` invocation at `:647`), and the terminal
`emit_decision allow ""` sits at `:659`. **The marker-absent exit at `:102-104` runs before any of
that code is reached at all** -- not merely before the decision, before the hookify call exists as
reachable code in that process's execution. In a repository with no active Phase 6 initiative (the
resting state of every adopting project outside an active implementation wave), `edm-gateguard`
never sources `edm-hookify`, never builds `GG_HOOKIFY_PAYLOAD`, and never runs `edm-hookify eval
file` -- zero subprocesses, exactly as the surrounding comment (`:6-9`, `:30-39`) says is the
performance intent for the "no active Phase 6" fast path. That intent is explicitly why this
routing exists; the question CA-122 raises is whether the *rules feature* was meant to inherit that
scoping too, silently, as a side effect.

**Contrast with the other two events, confirming this is specific to `file`**:
- `edm-bash-gate` has no marker check anywhere in the file -- I read the whole 140-line script
  above; the only gates before rule evaluation are the two `EDM_HOOKIFY*` kill switches
  (`:89-94`) and `command -v edm-hookify`/`jq` (`:99-100`). `bash`-event rules are unconditionally
  live.
- `edm-stop-gate` evaluates `stop`-event rules whenever `edm-state active-initiatives` returns at
  least one active initiative in **any** phase 1-6 (`:169`, `[[ ${#ACTIVE_PREFIXES[@]} -eq 0 ]] &&
  exit 0`) -- a broader condition than "Phase 6 specifically," and its own header documents this
  scoping explicitly (`:9-14`, `:224-227`).

So of the three events, only `file` is gated behind the narrowest possible condition (an active
Phase 6, specifically, not merely an active initiative), and only `file`'s scoping was, at the time
of the original audit, undocumented.

### What I established -- documentation state (this is a live, not historical, discrepancy)

`plugins/edm/CLAUDE.md`'s canonical "Hookify rule format (canonical)" section **already documents
this scoping today**, in the current working tree (not just in the historical audit snapshot):

> "the `file` event is evaluated by `edm-gateguard` **only on its allow path, and only while a
> Phase-6 marker is present** -- a repository with no active Phase 6 initiative evaluates no `file`
> rule at all (CA-122)"

This confirms the documentation half of CA-122's original finding has since been remediated in
`CLAUDE.md`. **`README.md` has not been brought into line.** `README.md:315-349` ("Rules as data --
`.claude/edm-hookify/*.json`") documents the feature with zero mention of Phase-6 scoping anywhere
in that section, and its one worked example (`:326-338`) uses `"event": "file"` (a
`warn-no-console-log` rule) presented as unconditionally live, general-purpose project enforcement:
"Your project can add its own enforcement without forking the plugin. Drop JSON rule files in
`.claude/edm-hookify/`..." (`:317-318`) -- no caveat, no cross-reference to the Phase-6 gating that
`CLAUDE.md` states elsewhere. A reader of `README.md` alone -- which is the document a new adopting
team is most likely to read first -- has no way to learn that the exact example given only fires
while someone else's EDM initiative happens to be in Phase 6 in that repository. This is exactly
the state the docket's framing anticipated ("because the README I just wrote says it is").

### Open decision

**Is the Phase-6-only scoping of `file` rules intended design or an accidental hole, and either
way, what closes the live README/behavior mismatch?** Options:

1. **Hoist the hookify call above the marker early-exit**, guarded on the rule directory's
   existence (`[[ -d "${PROJECT_ROOT}/.claude/edm-hookify" ]]`) rather than on the marker, so a repo
   with no rules still pays zero subprocesses (preserving the fast-path intent) and a repo that HAS
   adopted rules gets them enforced regardless of Phase 6 state. This is REMEDIATION's stated
   preferred fix. Cost: this is a real behavior change to the gate's fast path, touching the exact
   file `CC7` (this docket's own carried constraint) pins to a closed 200-660 line range with one
   line of headroom at 659 -- any code added here has essentially no room left before that bound
   must itself be re-opened as a new decision (as D42/D47 already did twice). It also changes when
   `PROJECT_ROOT` needs to be resolved (currently only inside `edm-hookify` itself, per-call);
   moving the gate earlier in `edm-gateguard` may require resolving it there too, which is a second
   project-root resolution site in a file that CA-109 (Epic 3) already flags as having diverged
   resolvers elsewhere in the plugin -- worth coordinating with that decision rather than adding a
   fourth resolver.
2. **Document the scoping and leave the code as-is** -- the "minimum acceptable" fix REMEDIATION
   names. Cost: cheap (a `README.md` edit to match `CLAUDE.md`'s existing language, and update the
   worked example or annotate it), but it ratifies an asymmetry between the three events that has
   no stated design rationale anywhere I could find -- nothing in `architecture.md`, `decisions.md`,
   or `EDMV4-T45`'s own ticket text (`tickets/epics/06-hooks-and-codemaps.md:337-353`) explains
   *why* `file` rules should be narrower than `bash`/`stop` rules, only that the marker check was
   already there for gateguard's own core purpose (Phase 6 fact-forcing) and hookify was wired
   "reusing the payload it already parsed" on the allow path that check gates. That reads as an
   implementation-convenience side effect, not a deliberate scoping decision -- but I could not find
   a decisions.md entry that says so either way, which is itself the gap this docket exists to
   close.
3. **Split the difference**: keep the marker gate for performance but add a documented, honest
   framing that `file`-event rules are "Phase-6-scoped enforcement," a distinct and narrower
   sub-feature from `bash`/`stop`, and rename/reframe the README example so it does not imply
   general applicability. Cost: avoids the CC7 line-budget and resolver-duplication risk of option
   1, but permanently limits what a `file`-event rule can be used for (no adopting team can use it
   for always-on file-content enforcement, only "during an EDM Phase 6" enforcement), which may not
   match what teams actually want from "add your own enforcement."

---

## CA-063 -- `edm-bash-gate` is a sixth undeclared `bin/` script

### What I established

`plugins/edm/bin/edm-bash-gate` exists on disk, 140 lines, executable, fully wired into
`hooks/hooks.json:90-96` as the first (ungated) entry of the `PreToolUse Bash` matcher block, and
is documented in `CLAUDE.md`'s `bin/` helper-scripts table (the `edm-bash-gate` row, present in the
current file) and in `README.md:367`. It is a real, shipped, in-use deliverable -- this is not a
dead or orphaned file.

**Cross-checked against the three cross-cutting tickets REMEDIATION names, all three confirmed to
name four scripts, never five:**

- **`EDMV4-T50`** ("Extend the tree-wide bash-4 construct ban..."),
  `tickets/epics/08-cross-cutting.md:35` (Target Components) and `:60-65` (AC1): AC1's own text
  names exactly five files by name -- `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`,
  `edm-stop-gate`, `edm-repo-readiness` -- and states the assertion "fails naming any of" those
  five "that is absent from it." `edm-bash-gate` is not in the list, in either the Target
  Components row or the AC text.
- **`EDMV4-T52`** ("Verify ASCII-only artifacts..."), `:254` (Target Components) and `:293-297`
  (AC4): AC4's coverage-assignment table names "the four new `bin/` scripts, the shared library and
  the two JSON config files" as owned by the byte-scan mechanism (AC2), without naming which four.
  Cross-referencing Target Components (`:254`, which lists `edm-gateguard`, `edm-hookify`,
  `edm-stop-gate` by name but not `edm-bash-gate` or `edm-repo-readiness`) and T50's five-name list
  above, "four" reads as `edm-gateguard`/`edm-hookify`/`edm-stop-gate`/`edm-repo-readiness` --
  `edm-bash-gate` again absent from the named enumeration. Note: AC2's actual mechanism (`find
  plugins/edm/bin -type f`, `:286-287`) is derived live, so `edm-bash-gate` almost certainly *is*
  swept by the real byte scan even though it is not named in AC4's coverage-assignment comment --
  the gap here is in the ticket's enumeration text, not necessarily in what the resulting test
  actually executes. I did not verify the live suite (no Bash), so I cannot confirm this beyond
  what the AC's own mechanism description implies.
- **`EDMV4-T53`** ("Land `wave8-smoke.sh`..."), `:413-416` (AC3): "Every new `bin/` script
  (`edm-gateguard`, `edm-hookify`, `edm-stop-gate`, `edm-repo-readiness`) has at least three cases
  in `wave8-smoke.sh`..." -- four names, explicit, `edm-bash-gate` absent.

**`EDMV4-T45`** (`tickets/epics/06-hooks-and-codemaps.md:323-420`), the ticket whose own Description
justifies `edm-bash-gate`'s existence ("The one place it cannot be avoided is `bash` rules, which
need a `Bash` matcher..."), lists its own Target Components (`:333`) as:
`hooks.json:80-90`/`:91-100`, `edm-gateguard (new)`, `edm-stop-gate (new)`, `edm-hookify (new)`, and
`CLAUDE.md`. **`edm-bash-gate` is not named as a Target Component of the very ticket that
necessitates it**, even though its ACs (AC3/AC4/AC9) describe the conditions under which a `Bash`
matcher block ships. This is the direct source of the gap: the ticket that authorizes the
`bash`-event wiring never lists the file that implements it as something it is producing.

### Open decision

**Is `edm-bash-gate` a deliverable that simply never got listed, or does its existence need a
fresh ticket to own it retroactively?** This is close to a formality compared to CA-113/CA-114, but
REMEDIATION is explicit that it belongs in the same commit as CA-004/CA-005 (the coverage findings
that depend on the same enumeration). Options:

1. **Amend the three ACs' name lists** (T50 AC1, T52 AC4's coverage table, T53 AC3) to add
   `edm-bash-gate`, and add it to `EDMV4-T45`'s Target Components retroactively in
   `decisions.md`. Cost: purely a documentation/ticket-text fix; no code changes; cheapest option
   and the one REMEDIATION recommends.
2. **File a follow-on ticket** that explicitly owns `edm-bash-gate` as its deliverable, closing the
   gap without touching already-closed tickets' text. Cost: more process overhead for the same
   outcome; only preferable if amending closed tickets' ACs after the fact is against this
   project's own conventions (I found no such convention stated against it -- `decisions.md`
   routinely records retroactive reconciliations, e.g. exactly this pattern for CA-065 in the same
   REMEDIATION document).

Either way, this finding does not, on its own, indicate the code is wrong -- only that the paper
trail (which ticket authorized which file) has a hole where `edm-bash-gate` should be.

---

## Summary table

| Finding | File:line (current) | What's established | What's open |
|---|---|---|---|
| CA-114 | `edm-hookify:200,279,335,396-402`; no `timeout` anywhere in `bin/` | Cap is input-length-only, uniform across operators; no pattern-complexity check; no wall-clock bound; header's cost-bounding claim is analytically false for catastrophic backtracking; `stop` event cannot carry `regex_match` at all (no valid fields); `bash` event is unconditionally live and is the widest blast radius | Timing demonstration and `timeout`/`gtimeout` availability **not executed** (no Bash tool available to this explorer) -- do this before deciding a fix. Four fix options costed above, none free. |
| CA-113 | `edm-gateguard:646-651,199-247`; `edm-hookify:225-227,414-425`; `edm-stop-gate:120-124,216,244`; `edm-bash-gate:136` | Three sanitization passes exist, all byte-safety only, zero provenance framing anywhere; `edm-stop-gate` is the only consumer that labels the text's origin at all (a bare descriptive prefix, not a trust frame) | Four options costed above: explicit untrusted-content frame, length cap, remove message from the operator-facing string entirely, or accept as documented risk. |
| CA-116 | `hooks.json:82`; `edm-gateguard:604-620`; `decisions.md` D26, D44 | D26's re-test condition is unambiguous and unmet; D44 formally carries it to `EDMRT`, D15-classed; `EDMRT` was never created (confirmed via glob, zero hits); shipped arm's dual-shape tolerance is admittedly a guess in its own code comment; my own toolset's MultiEdit absence is not evidence about the host in general | Three options costed above: reconcile the ledger honestly, actually re-test (blocked on host/tool availability this tree has no evidence exists), or withdraw the arm pending verification. |
| CA-122 | `edm-gateguard:100-104,627-659`; `CLAUDE.md` (Hookify section, current); `README.md:315-349` | Marker-absent exit is unconditional and precedes the hookify call entirely; `bash`/`stop` events have no such gating; `CLAUDE.md` already documents the `file`-scoping (remediated since the original audit), but `README.md`'s worked example still presents it as unconditional, with zero caveat | No decisions.md entry found explaining the scoping as deliberate design vs. implementation side effect. Three options costed above, with CC7's 1-line headroom on `edm-gateguard` and CA-109's resolver-duplication risk both bearing directly on option 1's cost. |
| CA-063 | `edm-bash-gate` (140 lines, shipped, wired, documented); T50/T52/T53/T45 ticket text | All three cross-cutting ACs (T50 AC1, T52 AC4, T53 AC3) name exactly four scripts, never five; T45's own Target Components omit the file its own Description justifies | Two options costed above: amend the closed tickets' text, or file a follow-on. Lowest-stakes of the five. |
