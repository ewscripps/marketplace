---
name: code-review
description: Execute the Code Review workflow for a Jira code review issue. Use when performing a code review for a release, epic, task, or bug. Handles the complete CR0-CR10 lifecycle including diff review, criteria verification, findings compilation, and remediation task creation.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__MCP_DOCKER__sequentialthinking, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_get_transitions, mcp__MCP_DOCKER__jira_transition_issue, mcp__MCP_DOCKER__jira_add_comment, mcp__MCP_DOCKER__jira_create_issue, mcp__MCP_DOCKER__jira_create_issue_link, mcp__MCP_DOCKER__read_graph, mcp__MCP_DOCKER__create_entities, mcp__MCP_DOCKER__create_relations, mcp__MCP_DOCKER__add_observations, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset, mcp__MCP_DOCKER__read_file, mcp__MCP_DOCKER__read_multiple_files, mcp__MCP_DOCKER__write_file, mcp__MCP_DOCKER__edit_file, mcp__MCP_DOCKER__list_directory, mcp__MCP_DOCKER__directory_tree, mcp__MCP_DOCKER__search_files, mcp__MCP_DOCKER__create_directory, mcp__MCP_DOCKER__move_file, mcp__MCP_DOCKER__get_file_info
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira code review issue key is: $ARGUMENTS

Execute all phases in strict sequential order (CR0-CR10). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
