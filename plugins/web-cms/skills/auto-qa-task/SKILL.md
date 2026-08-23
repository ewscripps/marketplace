---
name: auto-qa-task
description: Clones the Jira dev task you're working on into a linked "QA Task" in the same project and epic, links the two issues with the "Tests" relationship, and transitions the original dev task to "Dev Complete". Use when the user says things like "mark this dev complete", "clone this to QA", "create a QA task for this", or "hand this off to QA".
user-invocable: true
argument-hint: "[PROJ-123]"
disable-model-invocation: false
allowed-tools: Bash, AskUserQuestion, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_atlassian__jira_get_transitions, mcp__plugin_web-cms_atlassian__jira_transition_issue, mcp__plugin_web-cms_atlassian__jira_add_comment
model: sonnet
effort: medium
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for the source dev task is: $ARGUMENTS

Execute all phases in strict sequential order (AQ0-AQ6). Do not skip, reorder, or combine any phases. Do not create, link, or transition anything until the confirmation gate is approved.
