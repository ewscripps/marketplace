---
name: manual-qa-plan
description: Generate a manual QA verification plan for a Jira task, bug, or epic by reviewing the work item context and the related branch diff. Use when implementation already exists and you want tester-friendly verification steps covering prerequisites, expected results, regressions, and edge cases, then append the final QA plan to the Jira issue description.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Glob, Grep, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_search, mcp__MCP_DOCKER__jira_update_issue, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset, mcp__MCP_DOCKER__read_file, mcp__MCP_DOCKER__read_multiple_files, mcp__MCP_DOCKER__write_file, mcp__MCP_DOCKER__edit_file, mcp__MCP_DOCKER__list_directory, mcp__MCP_DOCKER__directory_tree, mcp__MCP_DOCKER__search_files, mcp__MCP_DOCKER__create_directory, mcp__MCP_DOCKER__move_file, mcp__MCP_DOCKER__get_file_info
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this manual QA planning target is: $ARGUMENTS

Execute all phases in strict sequential order (Q0-Q4). Do not skip, reorder, or combine any phases. Stop and report in the chat if any phase fails.
