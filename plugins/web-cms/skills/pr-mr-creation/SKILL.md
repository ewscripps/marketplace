---
name: pr-mr-creation
description: Execute the PR/MR Creation workflow to create a pull request on GitHub or a merge request on GitLab. Handles the complete M0-M6 lifecycle including platform detection, branch validation, Jira context, diff review, description generation, and PR/MR creation.
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__MCP_DOCKER__sequentialthinking, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_search, mcp__MCP_DOCKER__read_graph, mcp__MCP_DOCKER__create_entities, mcp__MCP_DOCKER__create_relations, mcp__MCP_DOCKER__add_observations, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset, mcp__MCP_DOCKER__read_file, mcp__MCP_DOCKER__read_multiple_files, mcp__MCP_DOCKER__write_file, mcp__MCP_DOCKER__edit_file, mcp__MCP_DOCKER__list_directory, mcp__MCP_DOCKER__directory_tree, mcp__MCP_DOCKER__search_files, mcp__MCP_DOCKER__create_directory, mcp__MCP_DOCKER__move_file, mcp__MCP_DOCKER__get_file_info
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (M0-M6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
