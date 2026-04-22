---
name: test-doc-review
description: Execute an independent test and documentation review for a Jira task or bug issue, or for the current repository state without Jira context. Use when core implementation already exists and you want to invoke the `test-reviewer` and `documentation-reviewer` sub-agents outside the main task or bug workflows. Handles the complete TD0-TD5 lifecycle including optional issue discovery, diff gathering, context assembly, test review, documentation review, and a final summary.
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, Read, Glob, Grep, mcp__MCP_DOCKER__jira_get_issue, mcp__MCP_DOCKER__git_status, mcp__MCP_DOCKER__git_diff, mcp__MCP_DOCKER__git_diff_staged, mcp__MCP_DOCKER__git_diff_unstaged, mcp__MCP_DOCKER__git_log, mcp__MCP_DOCKER__git_show
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Optional Jira issue key for this work item: $ARGUMENTS

If no Jira issue key is provided, skip TD0 and begin at TD1 using repository-only context.

Execute all phases in strict sequential order (TD0-TD5), with TD0 skipped only when no Jira issue key is provided. Do not skip, reorder, or combine any other phases. Stop and report in the chat if any phase fails.
