---
name: requirements-intake
description: Execute the Requirements Intake workflow to define a new feature, tech debt item, research task, or upkeep task. Drives the complete R0-R5 process including stakeholder Q&A, codebase analysis, acceptance criteria, and Jira issue creation.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__createJiraIssue, mcp__claude_ai_Atlassian__editJiraIssue, mcp__claude_ai_Atlassian__createIssueLink, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (R0-R5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
