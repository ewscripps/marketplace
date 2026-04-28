---
name: implementation-discovery
description: Run implementation discovery to surface and iterate over approaches before starting requirements intake. Asks what you want to build or investigate, explores relevant codebase areas in parallel, presents either a single recommended approach or a ranked options comparison with trade-offs, then runs a focused verification round against the chosen approach to confirm findings hold and surface anything missed. Output is written to the session knowledge graph; the workflow ends with a handoff instructing the user to `/clear` and then run `/requirements-intake` in a fresh conversation, which will pick the discovery up automatically.
user-invocable: true
argument-hint: '[what you want to build or investigate]'
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (D0–D5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
