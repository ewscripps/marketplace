---
name: implementation-discovery
description: Run implementation discovery to surface and iterate over approaches before starting requirements intake. Asks what you want to build or investigate, explores relevant codebase areas in parallel, then presents either a single recommended approach or a ranked options comparison with trade-offs. Output is written to the session knowledge graph so requirements-intake picks it up automatically.
user-invocable: true
argument-hint: '[what you want to build or investigate]'
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, Skill, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (D0–D4). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
