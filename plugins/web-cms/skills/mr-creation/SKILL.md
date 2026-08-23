---
name: mr-creation
description: Execute the MR Creation workflow to create a merge request on GitLab. Use whenever the user is ready to open a merge request or says "create an MR", "open a merge request", or "push this to review" — invoke without arguments to start a guided MR setup that pulls Jira context automatically. Handles the complete M0-M8 lifecycle including branch validation, branch sync and conflict resolution, Jira context, diff review, description generation, MR creation, and an automated code-review-bot response round.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_gitlab__gitlab_create_merge_request, mcp__plugin_web-cms_gitlab__gitlab_get_merge_request, mcp__plugin_web-cms_gitlab__gitlab_list_merge_requests, mcp__plugin_web-cms_gitlab__gitlab_list_merge_request_notes, mcp__plugin_web-cms_gitlab__gitlab_create_merge_request_note, mcp__plugin_web-cms_serena__onboarding
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (M0-M8). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
