---
name: code-review-intake
description: Execute the Code Review Intake workflow to set up a code review. Gathers review context through conversation, verifies the Jira issue and branch, asks clarifying questions, and creates a fully populated Jira Code Review issue.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__createJiraIssue, mcp__claude_ai_Atlassian__editJiraIssue, mcp__claude_ai_Atlassian__createIssueLink
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (CI0-CI5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
