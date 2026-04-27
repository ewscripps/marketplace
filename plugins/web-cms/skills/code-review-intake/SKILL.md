---
name: code-review-intake
description: Execute the Code Review Intake workflow to set up a code review. Gathers review context through conversation, verifies the Jira issue and branch, asks clarifying questions, and creates a fully populated Jira Code Review issue.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (CI0-CI5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
