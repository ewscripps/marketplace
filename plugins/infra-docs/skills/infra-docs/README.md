# infra-docs

A Claude Code skill that makes Scripps infrastructure documentation come out the same
way every time — placement, style, brevity, diagrams and a periodic freshness check.

Written for the Confluence space `Infra` at `ewscripps.atlassian.net`.

## What it covers

| | |
|---|---|
| **Hierarchy** | Where a page belongs in the space, the canonical per-system page set, what goes on which page |
| **Style** | The house voice, structure and formatting used by the pages written from September 2026 onward |
| **Wording** | Every sentence passed through ASD-STE100 Simplified Technical English, then linted |
| **Brevity** | The layering rule — the wiki is the distilled operator layer, the repo keeps the deep reference |
| **Diagrams** | Graphviz to SVG, aspect-ratio discipline, sources committed next to the code |
| **Refresh** | A materiality rubric so only changes that affect architecture, security or operations trigger a doc update |

Scope is devops/infrastructure documentation. It deliberately does not apply to
application READMEs, code comments or general writing.

## Install

Ships as the `infra-docs` plugin in the STG marketplace, bundled with the
[`asd-ste100`](../asd-ste100/README.md) skill (Simplified Technical English) that the
Write step uses. In Claude Code:

```
/plugin marketplace add git@gitlab.com:scripps/public/marketplace.git
/plugin install infra-docs@stg-marketplace
```

Already have the marketplace? `/plugin marketplace update stg-marketplace` first. If you
previously symlinked the skill into `~/.claude/skills/infra-docs`, remove the link so the
old copy does not shadow the plugin.

Then invoke it with `/infra-docs`, or just describe the task — the description is
written so it triggers on infrastructure documentation work without being asked for by
name.

**Manual fallback** (no plugin support): link both skill directories into
`~/.claude/skills/` (`%USERPROFILE%\.claude\skills\` on Windows) as siblings — infra-docs
reads `../asd-ste100/` when the Skill call is unavailable. Per-OS link and copy commands
are in [references/platforms.md](references/platforms.md).

## Setup

`ATLASSIAN_EMAIL` and `ATLASSIAN_API_TOKEN` must be in the environment. On macOS they
live in `~/.config/zsh/secrets.zsh` and are **not exported into non-interactive shells**,
which is why scripts that work in your terminal fail under an agent:

```bash
source ~/.zshenv
```

Diagram rendering needs Graphviz:

| | |
|---|---|
| macOS | `brew install graphviz` |
| Linux / WSL | `sudo apt install graphviz` |
| Windows | `winget install Graphviz.Graphviz` |

mermaid-cli only if a repo still has `.mmd` sources.

**On Windows, invoke Python as `py -3`**, never `python3` — Windows ships an alias of
that name that opens the Microsoft Store and does nothing. Credentials for PowerShell,
the `dot -c` plugin fix and the rest are in
[references/platforms.md](references/platforms.md).

## Layout

```
SKILL.md                              trigger, workflow spine, routing table
references/
  platforms.md                        setup, credentials and per-OS gotchas
  hierarchy-and-placement.md          where pages go, what the page set is
  house-style.md                      voice, structure, formatting
  confluence-mechanics.md             API behaviour, auth, attachments, gotchas
  diagrams.md                         Graphviz to SVG standard
  refresh-and-materiality.md          what counts as worth documenting
  verification.md                     proving it right, before and after
assets/
  confluence.py                       tree / publish / attach / verify / provenance
  render.py                           renders every source + legibility check
  ste_check.py                        strips page HTML, runs the asd-ste100 linter
  diagram-preamble.dot                shared palette and node defaults
  page-skeleton.html                  house-style page template
```

`SKILL.md` stays short on purpose. The references load only when the task needs them.

## Tooling

```bash
source ~/.zshenv                              # Windows: see platforms.md
python3 assets/confluence.py tree       --page <id>   # Windows: py -3 ...
python3 assets/confluence.py publish    --parent <id> --title "..." --file page.html
python3 assets/confluence.py attach     --page <id> --file d.svg --place-before '<h2>X'
python3 assets/confluence.py verify     --page <id>
python3 assets/confluence.py provenance --page <id> [--stamp <sha>]
python3 assets/ste_check.py page.html            # STE lint of the page prose
```

Every subcommand's raw `curl` equivalent is in
[references/confluence-mechanics.md](references/confluence-mechanics.md), so the standard
still works if the script is unavailable or the API shifts.

## Worked example

`Infra > Services > AWS > AWS Org Networking` is the reference implementation: six
pages, two Graphviz SVG diagrams, provenance on every page, with the deep reference left
in `iac/ews-services/aws-org-networking/docs/`.

## Why these rules exist

Each non-negotiable in `SKILL.md` maps to something that actually went wrong:

- Facts derived from the repo's own prose would have published wrong CIDRs, a wrong VPC
  endpoint count and superseded routing — all of it internally consistent and confident.
- Six diagrams shipped as cropped screenshots of a live editor, complete with the zoom
  widget and placeholder `X.X.0.0/16` CIDRs.
- A page title collided silently and became "… (2)".
- Pre-escaped HTML published the escape sequences, visibly.
