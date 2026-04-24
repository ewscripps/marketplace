---
name: epic-card
description: Execute the Epic Card workflow for a Jira epic. Use when beginning work on an epic that needs to be broken down into child tasks. Handles the complete E0-E11 lifecycle including breakdown planning, child task creation, sequential execution, user testing, and epic summary.
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__getTransitionsForJiraIssue, mcp__claude_ai_Atlassian__transitionJiraIssue, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createJiraIssue, mcp__plugin_web-cms_serena__check_onboarding_performed, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira epic key is: $ARGUMENTS

Execute all phases in strict sequential order (E0-E11). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
