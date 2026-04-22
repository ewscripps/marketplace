---
name: task-card
description: Execute the Task Card workflow for a Jira task issue. Use when beginning work on a feature, tech debt, research, or upkeep task. Handles the complete T0-T12 lifecycle including planning, core implementation, dedicated test/documentation completion, user testing, and summary of changes.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_get_transitions, mcp__MCP_DOCKER__jira_transition_issue, mcp__MCP_DOCKER__jira_add_comment, mcp__MCP_DOCKER__check_onboarding_performed, mcp__MCP_DOCKER__onboarding, mcp__MCP_DOCKER__get_symbols_overview, mcp__MCP_DOCKER__find_symbol, mcp__MCP_DOCKER__find_referencing_symbols, mcp__MCP_DOCKER__search_for_pattern, mcp__MCP_DOCKER__replace_symbol_body, mcp__MCP_DOCKER__insert_after_symbol, mcp__MCP_DOCKER__insert_before_symbol, mcp__MCP_DOCKER__rename_symbol, mcp__MCP_DOCKER__safe_delete_symbol, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this task is: $ARGUMENTS

Execute all phases in strict sequential order (T0-T12). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
