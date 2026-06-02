---
name: compact-context
description: Manually trigger a context compaction checkpoint during any active web-cms workflow session. Reads the current knowledge graph state, writes a phase_handoff entity to capture the current phase position, and prompts the user to run /compact. Use at any point mid-workflow when context is growing full and the workflow is between designated compaction gates.
user-invocable: true
argument-hint: ""
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__open_nodes, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
model: sonnet
effort: low
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute phases C0 through C3 in strict sequential order. Stop immediately if no active session is found in C0.
