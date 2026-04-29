---
name: design-intake
description: Execute the Design Intake workflow to define specifications around a new feature with a focus on design details — colors, typography, spacing, component states, and accessibility. Accepts Claude Design HTML exports, mockup images, or verbal specs as input. Use as the handoff step after a Claude Design session.
user-invocable: true
disable-model-invocation: false
model: opus
effort: high
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (R0-R6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
