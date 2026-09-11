# Deprecated Scope Protocol

Some repositories carry features that **still execute but are no longer supported**. This document is the
single contract for how the plugin's skills and agents handle them.

It has two halves:

- **Producer** (§5) -- `project-onboarding` discovers candidates, has the user declare which are real, and
  writes the declared inventory into the repository's own documentation.
- **Consumers** (§1-§4) -- every other skill and agent reads that inventory and refuses to extend, test,
  or plan work against it.

The halves are coupled by the exact headings in §5. A producer that emits a different heading silently
breaks every consumer, because the §1 lookup will not resolve.

---

## §1 Lookup order

Resolve the declared inventory at the git worktree root, in this order:

1. `CLAUDE.md` -- a section whose heading matches `Deprecated`, `Do not extend`, `Unsupported`, `Legacy`,
   or `Do not touch` (case-insensitive). This is the authoritative rule, and it usually names each feature
   in a `| Feature | Do not |` table.
2. Any document that section points to -- commonly a `CONTEXT.md` section headed
   `Deprecated / unsupported`, which carries the full footprint per feature: entry-point classes,
   directory paths, template filename patterns, generated-code packages, query parameters, and runtime
   switches.
3. A nested `CLAUDE.md` **or `README.md`** in any directory in scope. Repositories differ on which name
   they use for per-module docs, so check both -- a project whose convention is `README.md` keeps its
   local deprecation notes there. A producer following §5 also lists these paths in the `CONTEXT.md`
   footprint, so prefer that list when it is present rather than searching.

If the repository declares no such inventory, record `no deprecated inventory declared` and continue
normally. Absence is a valid state, not an error, and every consumer behavior in §4 becomes a no-op.

## §2 Marker extraction and specificity

**Extract concrete markers**, not just feature names -- the strings that let you recognize the surface in
a diff, a file listing, or an instruction: directory paths, filename patterns (for example `*.amp.hbs`),
class or package prefixes, query parameters (for example `?_amp=true`), field and settings names.

**Keep markers specific.** A marker must be distinctive enough that it cannot match supported code -- a
filename pattern, a class or package prefix, a query parameter, a settings field. Never reduce a feature
to a common word that also appears in supported behavior, because an over-broad marker silently strips
legitimate work or coverage, and a false match is a worse failure than a verbose result.

If a supplied marker looks too broad to apply safely, say so in your report rather than acting on it.

## §3 The declared inventory is the only authority

**Do not infer deprecation** from code comments, `@deprecated` annotations, directory names, or staleness.
A `@deprecated` symbol is very often still-supported product behavior, and a quiet subtree is not a
retired one.

The single exception is `project-onboarding`'s discovery phases (§5), where such signals are gathered
explicitly as **candidates for the user to confirm** and are never treated as declarations until the user
declares them. No other skill or agent may originate a deprecation claim.

## §4 Consumer obligations

- **Exclude absolutely.** No plan step, test case, pass condition, prerequisite, screenshot request, or
  generated artifact may target a deprecated surface. This holds even when the work sits directly beside
  one, and even when the feature is still switched on somewhere: "unsupported" and "not currently serving
  traffic" are separate questions, and resolving the second is not the consumer's job.
- **Never write regression coverage for a deprecated feature.** Proximity to changed code does not justify
  it. If the risk is real it is a developer concern, not a QA step.
- **Flag, do not act.** If the work itself adds to or modifies a deprecated surface, that is usually
  accidental -- deprecated code commonly sits next to its supported counterpart, so copying a neighbouring
  file pulls it along. Report it, naming the file and the feature, so a human can remove it. Never convert
  it into a task, a case, or a silent fix.
- **Record the decision.** When something is dropped or excluded for this reason, say so explicitly, so it
  reads as a deliberate call and not an oversight.
- **Record the empty case.** When no inventory is declared, state that rather than staying silent -- a
  consumer that says nothing is indistinguishable from one that never checked.

## §5 Producer obligations

`project-onboarding` is the producer. What it writes is a machine-readable contract, not a formatting
preference.

### The three states

A single "dead code" list is what lets a deprecated feature hide, because the feature is not dead -- it
runs. Separate the three:

| State | Runs? | May new work build on it? |
|---|---|---|
| **Dead** | No | No -- safe to ignore entirely |
| **Deprecated / unsupported** | **Yes** | **No** -- functional but frozen; do not extend |
| **Dormant** | Yes, but does nothing | Not without adding an implementation first |

Only the middle state is the subject of this protocol.

### Required emissions

| Document | Heading (exact) | Must contain |
|---|---|---|
| `CLAUDE.md` | `Deprecated — do not extend` | A `\| Feature \| Do not \|` table, each row phrased as an **instruction** ("Do not create `.amp.hbs` templates"), plus a link to the `CONTEXT.md` section. Kept **separate** from any do-not-touch list -- don't-modify and don't-build-on are different rules. |
| `CONTEXT.md` | `Deprecated / unsupported` | The three-state table, then one subsection per feature carrying: entry points, footprint counts, generated code, runtime switch (if any), the newest sibling implementation's treatment, **a markers row per §2**, and the paths of any nested deprecation notes. |
| `CONTRIBUTING.md` | `Deprecating a feature` | The policy for adding to this inventory: annotate the code, record the footprint, state the rule, cite an in-repo annotation precedent where one exists. Deprecating is not deleting. |
| Nested module doc | any | One line naming the local rule, where a module contains deprecated surface. |

The `CLAUDE.md` heading matches §1 step 1 on `Do not extend`; the `CONTEXT.md` heading matches §1 step 2
verbatim. Changing either string breaks the lookup.

### What the footprint must answer

A consumer reading the `CONTEXT.md` subsection should be able to answer, without opening any code:

- What is the entry point, and does it still execute -- by what trigger?
- Is there a runtime switch, and what does toggling it actually change?
- Which concrete markers identify the surface?
- Is there a sibling implementation that already ignores it? (The strongest evidence a rule is real.)

State plainly what still runs. "Unsupported" does not mean "inert", and a consumer that assumes otherwise
will mis-scope its work.

---

## Who uses this

| Skill / agent | Role | Where |
|---|---|---|
| `project-onboarding` | **Producer** -- discovers, confirms, declares | O1 detection, O2 exploration, O3 interview, O4-O6 emission |
| `manual-qa-plan` | Consumer -- excludes from QA coverage | Q2 inventory build, Q3 hand-off, Q4 self-check |
| `manual-qa-reviewer` | Consumer -- excludes from generated cases | Supplied by the orchestrator |
| `comment-reviewer` | Consumer -- scans the drafted artifact for leaks | `Q4 — Final QA Plan` gate |
| `task-card`, `bug-card`, `epic-card` | Consumer -- refuses to plan extensions | T2/B3 inventory build; T4/B5/E4 self-interrogation |
| `codebase-explorer` | Consumer -- flags intersection as a risk | Any exploration |
| `code-quality-reviewer` | Consumer -- flags diffs that extend the surface | Review dimensions |
