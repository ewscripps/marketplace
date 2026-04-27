---
name: mr-creation
description: Execute the MR Creation workflow to create a merge request on GitLab. Handles the complete M0-M6 lifecycle including branch validation, Jira context, diff review, description generation, and MR creation.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_gitlab__gitlab_create_merge_request, mcp__plugin_web-cms_gitlab__gitlab_get_merge_request, mcp__plugin_web-cms_gitlab__gitlab_list_merge_requests
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (M0-M6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
