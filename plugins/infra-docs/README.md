# infra-docs plugin

Infrastructure documentation for the Scripps Confluence `Infra` space, written in
ASD-STE100 Simplified Technical English. Maintained by the infra team.

| Skill | Invoke | What it does |
|---|---|---|
| `infra-docs` | `/infra-docs:infra-docs [publish \| refresh \| diagram] [repo path]` | Page placement, house style, Graphviz diagrams, materiality-gated refresh. See [skills/infra-docs/README.md](skills/infra-docs/README.md). |
| `asd-ste100` | `/infra-docs:asd-ste100` | Rewrites prose so it cannot be misread. infra-docs calls it at the Write step; it also works on its own. |

## Install

```
/plugin marketplace add git@gitlab.com:scripps/public/marketplace.git
/plugin install infra-docs@stg-marketplace
```

Remove any old `~/.claude/skills/infra-docs` or `~/.claude/skills/asd-ste100` links
first, so the manual copies do not load alongside the plugin.

## Vendored skill

`skills/asd-ste100` is a vendored copy of
[danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) v0.4.0, MIT
licensed — keep its `LICENSE` file. To update, replace the directory with the new
upstream release and bump this plugin's version in `.claude-plugin/marketplace.json`.
Do not edit it in place; infra-specific rules belong in
`skills/infra-docs/references/house-style.md`.
