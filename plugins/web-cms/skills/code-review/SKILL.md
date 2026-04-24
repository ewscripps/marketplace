---
name: code-review
description: Execute the Code Review workflow for a Jira code review issue. Use when performing a code review for a release, epic, task, or bug. Handles the complete CR0-CR10 lifecycle including diff review, criteria verification, findings compilation, and remediation task creation.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__getTransitionsForJiraIssue, mcp__claude_ai_Atlassian__transitionJiraIssue, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createJiraIssue, mcp__claude_ai_Atlassian__createIssueLink, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_serena__get_symbols_overview, mcp__plugin_web-cms_serena__find_symbol, mcp__plugin_web-cms_serena__find_referencing_symbols, mcp__plugin_web-cms_serena__search_for_pattern
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira code review issue key is: $ARGUMENTS

Execute all phases in strict sequential order (CR0-CR10). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
