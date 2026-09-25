---
name: infra-docs
description: Publishes and maintains infrastructure documentation in the Scripps Confluence Infra space. Covers where a page belongs in the hierarchy, the house style, diagram tooling (Graphviz to SVG), and a materiality-gated refresh that updates pages only when architecture, security or operations actually changed. Use when documenting or updating an infrastructure repo — OpenTofu/Terraform estates, networking, clusters, platform services — or when asked to publish to, refresh, restructure or add diagrams to Confluence infra pages. Do NOT use for application README files, code comments, general writing, or non-infrastructure Confluence spaces.
version: 2
user-invocable: true
argument-hint: '[publish | refresh | diagram] [repo path]'
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Skill
---

# Infrastructure Documentation

Operator-facing documentation for infrastructure repos, published to Confluence space
`Infra` at `ewscripps.atlassian.net`.

## What this governs

The **layering** between a repo and the wiki, the **placement** of pages in the space,
the **house style**, the **diagram pipeline**, and a **periodic refresh** gated on
material change.

The audience is a human operator who needs an answer fast — "I need a subnet", "which
account owns this CIDR", "traffic works one direction only". Overly verbose
documentation gets ignored, so brevity is a correctness property here, not a nicety.

## When this applies

Use it when the subject is infrastructure: an IaC estate, networking, a cluster, a
platform service, a runbook, or the Confluence pages describing any of those.

Do **not** use it for application READMEs, code comments, ADRs inside a codebase,
general writing, or Confluence spaces other than `Infra`.

## Three modes

| Mode | Trigger | Start at |
|---|---|---|
| **publish** | A system has no Confluence pages yet, or needs restructuring | Workflow A below |
| **refresh** | Pages exist; check whether code has moved materially since | Workflow B below |
| **diagram** | Add or fix a diagram on an existing page | [diagrams.md](references/diagrams.md) |

## Routing

| Need | Read |
|---|---|
| Where does this page belong? What is the page set? | [hierarchy-and-placement.md](references/hierarchy-and-placement.md) |
| How should it read? Voice, structure, what to leave out | [house-style.md](references/house-style.md) |
| Is each sentence plain and impossible to misread? | The `asd-ste100` skill — see Workflow A step 4 |
| Publishing mechanics, links, macros, attachments, auth | [confluence-mechanics.md](references/confluence-mechanics.md) |
| Diagram authoring and rendering | [diagrams.md](references/diagrams.md) |
| Is this change worth documenting? | [refresh-and-materiality.md](references/refresh-and-materiality.md) |
| Proving it is right before and after publishing | [verification.md](references/verification.md) |
| Setup, credentials or a tool missing on this machine | [platforms.md](references/platforms.md) |

Tooling: `assets/confluence.py` wraps the REST calls and `assets/render.py` renders
diagrams. Every subcommand's raw `curl` equivalent is documented in
[confluence-mechanics.md](references/confluence-mechanics.md), so the skill still works
if the script is unavailable.

**Platform:** commands below are written for macOS/Linux. On Windows invoke Python as
`py -3`, not `python3` — a `python3` call there silently opens the Microsoft Store and
does nothing. Credentials, installs and Windows-specific failures are in
[platforms.md](references/platforms.md).

## Non-negotiables

These are the failures this standard exists to prevent. Each one has actually happened.

1. **Derive every fact from source code, never from existing prose.** Prose drifts. The
   first pass at the networking docs would have published wrong CIDRs, a wrong endpoint
   count and superseded routing, all copied faithfully from the repo's own `docs/`.

2. **Record provenance on every page.** One line, verbatim shape:
   `Verified as of <date> against ` + backticked repo path + backticked `<branch> <sha>`.
   This is not decoration — it is the anchor the refresh mode diffs against.

3. **Confluence bodies are HTML, not storage XML.** `<ac:structured-macro>` renders as
   literal text. Do not pre-escape entities; passing `&lt;p&gt;` publishes the escape
   sequence, visibly.

4. **Page titles are unique per space.** A collision is not an error — Confluence
   silently appends " (2)" and you will not notice until someone reports the wrong link.

5. **Diagrams are SVG, rendered at native size.** Never a screenshot of an editor
   viewport. Six diagrams were published as 1063x1289 cropped screenshots with the
   editor's zoom widget baked in and placeholder `X.X.0.0/16` CIDRs in the boxes.

6. **A table beats a diagram for anything enumerable.** CIDR allocations, account maps
   and rule lists are tables. A table cannot drift the way a rendered picture can, and it
   sorts and copy-pastes.

7. **If it changes every sprint, it belongs in the repo, not the wiki.** Confluence is
   the distilled operator layer; `docs/` stays the deep reference next to the code.

## Workflow A — publishing a system

1. **Survey before creating.** Read the space tree and the sibling subtrees to infer
   convention. See [hierarchy-and-placement.md](references/hierarchy-and-placement.md).
   Confirm the parent page with the user before creating anything.
2. **Derive the facts from code.** Parse the `.tf` (or equivalent) files. Note every
   place the repo's own prose disagrees — that is a finding to report, not to silently
   copy or silently fix.
3. **Choose the page set.** Default six; minimum three. Each page must answer a question
   operators actually ask. Drop any page you cannot justify that way.
4. **Write**, following [house-style.md](references/house-style.md). Then run the
   drafted prose through the `asd-ste100` skill (Simplified Technical English), bundled
   in this plugin as `infra-docs:asd-ste100`. If the Skill call fails, read
   [../asd-ste100/SKILL.md](../asd-ste100/SKILL.md) and apply it directly.
   - **Strict** mode for procedures: runbook steps, troubleshooting fixes, command
     sequences.
   - **STE-flavored** mode for architecture and overview prose.
   - **Leave alone:** code, commands, resource names, tables of values, and the
     abstract and provenance lines, whose format is fixed.
   Where STE and house-style.md disagree, house-style.md wins — it encodes page
   structure; STE governs sentences.
5. **Publish** parent-first so children have a parent id.
   `confluence.py publish` — see [confluence-mechanics.md](references/confluence-mechanics.md).
6. **Diagrams last**, and only where a picture beats a table.
7. **Verify**, per [verification.md](references/verification.md). Report drift found in
   step 2 back to the user as a separate, reviewable change.

## Workflow B — refreshing a system

1. Read the provenance SHA off each published page.
2. Validate it resolves in git. If not, fall back to the provenance date, mark the run
   DEGRADED, and re-derive rather than apply deltas.
3. Classify commits since the baseline with the materiality rubric in
   [refresh-and-materiality.md](references/refresh-and-materiality.md).
   **Commit type prefixes must never gate the decision** — in practice they are wrong
   often enough to be actively misleading.
4. For anything MATERIAL, re-derive the affected table at baseline and at HEAD. Publish
   only if the rendered rows differ. Any prose you rewrite gets the same STE pass as
   Workflow A step 4.
5. Stamp provenance on every page in the set, including unchanged ones — a
   NOT-MATERIAL verdict is still a verification.

Detection can run unattended; **publication should not**. Rewriting prose about a live
production network without a human reading it is not worth the risk.
