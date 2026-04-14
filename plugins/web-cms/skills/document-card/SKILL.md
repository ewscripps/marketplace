---
name: document-card
description: Generate user-facing documentation for a completed Jira task, epic, or bug. Reads the completed work item, uses Playwright to capture UI flows with screenshots in a staging environment, documents API changes in Postman, and publishes the result to a Confluence page.
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__MCP_DOCKER__sequentialthinking, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_add_comment, mcp__MCP_DOCKER__browser_navigate, mcp__MCP_DOCKER__browser_snapshot, mcp__MCP_DOCKER__browser_take_screenshot, mcp__MCP_DOCKER__browser_click, mcp__MCP_DOCKER__browser_type, mcp__MCP_DOCKER__browser_fill_form, mcp__MCP_DOCKER__browser_select_option, mcp__MCP_DOCKER__browser_press_key, mcp__MCP_DOCKER__browser_wait_for, mcp__MCP_DOCKER__browser_tabs, mcp__MCP_DOCKER__browser_close, mcp__MCP_DOCKER__confluence_search, mcp__MCP_DOCKER__confluence_get_page, mcp__MCP_DOCKER__confluence_create_page, mcp__MCP_DOCKER__confluence_upload_attachment, mcp__MCP_DOCKER__confluence_upload_attachments, mcp__MCP_DOCKER__confluence_add_label, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset, mcp__MCP_DOCKER__read_file, mcp__MCP_DOCKER__read_multiple_files, mcp__MCP_DOCKER__write_file, mcp__MCP_DOCKER__edit_file, mcp__MCP_DOCKER__list_directory, mcp__MCP_DOCKER__directory_tree, mcp__MCP_DOCKER__search_files, mcp__MCP_DOCKER__create_directory, mcp__MCP_DOCKER__move_file, mcp__MCP_DOCKER__get_file_info
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this work item is: $ARGUMENTS

Execute all phases in strict sequential order (D0-D8). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
