---
name: bug-card
description: Execute the Bug Card workflow for a Jira bug issue. Use when beginning work on a bug fix. Handles the complete B0-B15 lifecycle including reproduction, root cause investigation, fix planning, core implementation, dedicated test/documentation completion, user testing, and summary of changes.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_get_transitions, mcp__plugin_web-cms_atlassian__jira_transition_issue, mcp__plugin_web-cms_atlassian__jira_add_comment, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities, mcp__plugin_web-cms_serena__get_symbols_overview, mcp__plugin_web-cms_serena__find_symbol, mcp__plugin_web-cms_serena__find_referencing_symbols, mcp__plugin_web-cms_serena__search_for_pattern, mcp__plugin_web-cms_serena__replace_symbol_body, mcp__plugin_web-cms_serena__insert_after_symbol, mcp__plugin_web-cms_serena__insert_before_symbol, mcp__plugin_web-cms_serena__rename_symbol, mcp__plugin_web-cms_serena__safe_delete_symbol
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this bug is: $ARGUMENTS

Execute all phases in strict sequential order (B0-B15). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
