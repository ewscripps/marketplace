# House style

Derived from the pages written in September 2026 — `Stacker — Architecture`
(`3822321700`), `Architecture Overview` (`3822288901`), `Troubleshooting and Known
Gotchas` (`3822223383`). Match these, not the older OneDrive-migrated pages.

Migrated pages open with a repeated H1 of the title and a **Type / Source / Last
Modified (OneDrive sync)** metadata table. **Do not reproduce that.** It marks a page as
imported rather than written.

## Page shape

```html
<p><em>One line: what this page covers, and which pages assume it.</em></p>

<p>Verified as of 19 September 2026 against <code>scripps/stg-ops/iac/…</code> <code>main cbdc84f</code>.</p>

<h2>An editorial claim, not a noun</h2>
<p>Thesis sentence first. Then a table for anything enumerable.</p>
```

- **No H1.** The page title carries it. Starting with `<h1>` duplicates the title.
- **Italic abstract**, one line, first.
- **Provenance line**, second. Not decoration — the refresh mode diffs against this SHA.
  See [refresh-and-materiality.md](refresh-and-materiality.md).
- **Number sections only on long architecture pages** (over ~2,000 words). Elsewhere
  numbering is noise.

## Voice

**H2s are claims, not labels.** They should carry information on their own, because
scanning headings is how operators read.

| Write | Not |
|---|---|
| `Egress is a four-hop chain, and every hop must stay in the same AZ` | `Egress` |
| `Two transit gateways that behave differently` | `Transit Gateways` |
| `The expensive failure: a route table that was never associated` | `Incident 2026-08-26` |
| `Workload NACLs are one rule from the quota ceiling` | `NACL Configuration` |

**State the present truth, including half-built state.** If two firewall rules are
marked temporary and still live, say so. If a CI job exists but was never wired up, say
that rather than describing the intent.

**Close every gotcha with a recognition signature and a remedy.** "How to recognise it:
every layer checks out and traffic still dies. What to do: check associations, not
routes."

**Sentences follow ASD-STE100.** After drafting, run the prose through the bundled
`asd-ste100` skill — Strict for procedures, STE-flavored for explanation (SKILL.md,
Workflow A step 4). This file still owns page shape: headings stay claims, and the
abstract and provenance lines keep their fixed form.

## Formatting

| Element | Rule |
|---|---|
| Tables | Preferred for anything enumerable. Prefer a table to a bulleted list. |
| Emphasis | **Bold prose.** The strongest signal is a bold imperative: **Do not apply it.** |
| Values | Every non-obvious value in `<code>`: CIDRs, account ids, resource names, flags |
| Panels | **None.** No info/note/warning panels, no status lozenges, no expands |
| Emoji | **None** |
| Dates | `<time datetime="2026-09-19">19 September 2026</time>` renders as a date lozenge |
| Code | `<pre><code class="language-bash">` |

The absence of panels is deliberate. Bold prose carries emphasis; a page of coloured
boxes reads as noise and hides the one thing that actually matters.

## Index pages

```html
<p><strong>Scope.</strong> What lives here and what does not.</p>
<h2>Contents</h2>
<!-- children macro -->
<p>Last reviewed <time datetime="2026-09-19">19 September 2026</time>.</p>
```

An index page should also carry a disambiguation table when the name is ambiguous, and
the two or three rules that will bite a newcomer before anything else does.

## Brevity

Verbose documentation gets ignored, which makes length a correctness problem.

- Six pages per system is the default ceiling, not a target.
- Every page earns its place by answering a question operators actually ask.
- Every table earns its place by being read, not by being complete.
- If a sentence does not change what the reader does, cut it.
- Deep reference goes in the repo. See the layering rule in
  [hierarchy-and-placement.md](hierarchy-and-placement.md).

## What not to write

- Do not restate what the table above already says.
- Do not explain AWS primitives. The audience operates this estate daily.
- Do not describe intent as though it were current state.
- Do not copy a table out of the repo that changes with the code — link to it.
