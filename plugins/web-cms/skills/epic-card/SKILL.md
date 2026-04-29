---
name: epic-card
description: Execute the Epic Card workflow for a Jira epic. Use when beginning work on an epic — invoke with the epic's Jira key whenever the user is starting work on an epic and needs it broken down into child tasks and executed sequentially. Handles the complete E0-E11 lifecycle including breakdown planning, child task creation, sequential execution, user testing, and epic summary.
user-invocable: true
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, Skill, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_get_transitions, mcp__plugin_web-cms_atlassian__jira_transition_issue, mcp__plugin_web-cms_atlassian__jira_add_comment, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira epic key is: $ARGUMENTS

Execute all phases in strict sequential order (E0-E11). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
