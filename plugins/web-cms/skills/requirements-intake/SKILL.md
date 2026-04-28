---
name: requirements-intake
description: Execute the Requirements Intake workflow to define a new feature, tech debt item, research task, or upkeep task. Use when starting a new piece of work that needs to be formally defined — invoke without arguments whenever the user wants to create a new Jira task or epic, define requirements, or start an intake session. Drives the complete R0-R6 process including stakeholder Q&A, codebase analysis, acceptance criteria, and Jira issue creation.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (R0-R6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
