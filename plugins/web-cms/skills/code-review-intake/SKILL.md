---
name: code-review-intake
description: Execute the Code Review Intake workflow to set up a code review. Use when the user wants to create a code review issue in Jira before performing a review — even if they just say "set up a code review" or "create a review card" without specifying a Jira key. Gathers review context through conversation, verifies the Jira issue and branch, asks clarifying questions, and creates a fully populated Jira Code Review issue ready for /code-review.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (CI0-CI5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
