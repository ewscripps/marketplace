---
name: issue-intake
description: Execute the Issue Intake workflow when encountering unexpected or missing behavior in the software. Use whenever something is not working as expected and it needs to be triaged — invoke without arguments when the user says "something's broken", "this doesn't work", or wants to report an issue before knowing if it's a bug or missing feature. Classifies the issue as a Bug or Missing Requirement through the I0-I6 process, then either creates a Jira Bug card or transitions into the Requirements Intake workflow.
user-invocable: true
argument-hint: '[optional: pre-populated context from a parent workflow]'
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

If $ARGUMENTS is non-empty, it contains pre-populated context from a parent workflow (e.g. a task-card or bug-card testing gate). Use this context to pre-populate I0 fields — confirm with the user that the details are accurate rather than starting from scratch. Map the args to: observed behavior, expected behavior, and any related Jira key for linking.

Execute all phases in strict sequential order (I0-I6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
