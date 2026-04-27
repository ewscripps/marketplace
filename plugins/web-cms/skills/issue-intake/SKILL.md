---
name: issue-intake
description: Execute the Issue Intake workflow when encountering unexpected or missing behavior in the software. Classifies the issue as a Bug or Missing Requirement through the I0-I5 process, then either creates a Jira Bug card or transitions into the Requirements Intake workflow.
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute all phases in strict sequential order (I0-I5). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
