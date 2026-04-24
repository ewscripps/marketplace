---
name: task-card
description: Execute the Task Card workflow for a Jira task issue. Use when beginning work on a feature, tech debt, research, or upkeep task. Handles the complete T0-T13 lifecycle including planning, core implementation, dedicated test/documentation completion, user testing, and summary of changes.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__getTransitionsForJiraIssue, mcp__claude_ai_Atlassian__transitionJiraIssue, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_serena__get_symbols_overview, mcp__plugin_web-cms_serena__find_symbol, mcp__plugin_web-cms_serena__find_referencing_symbols, mcp__plugin_web-cms_serena__search_for_pattern, mcp__plugin_web-cms_serena__replace_symbol_body, mcp__plugin_web-cms_serena__insert_after_symbol, mcp__plugin_web-cms_serena__insert_before_symbol, mcp__plugin_web-cms_serena__rename_symbol, mcp__plugin_web-cms_serena__safe_delete_symbol
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this task is: $ARGUMENTS

Execute all phases in strict sequential order (T0-T13). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
