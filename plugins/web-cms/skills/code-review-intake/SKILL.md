---
name: code-review-intake
description: Execute the Code Review Intake workflow to set up a code review. Gathers review context through conversation, verifies the Jira issue and branch, asks clarifying questions, and creates a fully populated Jira Code Review issue.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__jira_search, mcp__MCP_DOCKER__jira_create_issue, mcp__MCP_DOCKER__jira_update_issue, mcp__MCP_DOCKER__jira_create_issue_link, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_add, mcp__MCP_DOCKER__git_commit, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show, mcp__MCP_DOCKER__git_create_branch, mcp__MCP_DOCKER__git_checkout, mcp__MCP_DOCKER__git_reset
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (CI0-CI5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
