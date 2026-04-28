---
name: code-review
description: Execute the Code Review workflow for a Jira code review issue. Use when performing a code review for a release, epic, task, or bug. Handles the complete CR0-CR11 lifecycle including diff review, criteria verification, findings compilation, remediation task creation, and cleanup.
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_get_transitions, mcp__plugin_web-cms_atlassian__jira_transition_issue, mcp__plugin_web-cms_atlassian__jira_add_comment, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities, mcp__plugin_web-cms_serena__get_symbols_overview, mcp__plugin_web-cms_serena__find_symbol, mcp__plugin_web-cms_serena__find_referencing_symbols, mcp__plugin_web-cms_serena__search_for_pattern
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira code review issue key is: $ARGUMENTS

Execute all phases in strict sequential order (CR0-CR11). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
