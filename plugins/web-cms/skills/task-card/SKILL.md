---
name: task-card
description: Execute the Task Card workflow for a Jira task issue. Use when beginning work on a task — invoke with the Jira task key whenever the user says "work on this task", "implement PROJ-123", or starts a development session for a feature, tech debt, research, or upkeep task. Handles the complete T0-T13 lifecycle including planning, core implementation, dedicated test/documentation completion, user testing, and summary of changes.
user-invocable: true
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, Skill, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_get_transitions, mcp__plugin_web-cms_atlassian__jira_transition_issue, mcp__plugin_web-cms_atlassian__jira_add_comment, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_serena__get_symbols_overview, mcp__plugin_web-cms_serena__find_symbol, mcp__plugin_web-cms_serena__find_referencing_symbols, mcp__plugin_web-cms_serena__search_for_pattern, mcp__plugin_web-cms_serena__replace_symbol_body, mcp__plugin_web-cms_serena__insert_after_symbol, mcp__plugin_web-cms_serena__insert_before_symbol, mcp__plugin_web-cms_serena__rename_symbol, mcp__plugin_web-cms_serena__safe_delete_symbol, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this task is: $ARGUMENTS

Execute all phases in strict sequential order (T0-T13). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
