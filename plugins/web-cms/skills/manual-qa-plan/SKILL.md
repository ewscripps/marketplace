---
name: manual-qa-plan
description: Generate a manual QA verification plan for a Jira task, bug, or epic. Use when implementation is complete and a tester-friendly QA plan is needed — invoke with the Jira issue key whenever a task or bug has been implemented and needs verification steps before or during QA. Reviews the work item context and the related branch diff to produce prerequisites, expected results, regression scenarios, and edge cases, then appends the final QA plan to the Jira issue description.
user-invocable: true
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_update_issue
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this manual QA planning target is: $ARGUMENTS

Execute all phases in strict sequential order (Q0-Q4). Do not skip, reorder, or combine any phases. Stop and report in the chat if any phase fails.
