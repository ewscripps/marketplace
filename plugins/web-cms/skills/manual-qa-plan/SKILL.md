---
name: manual-qa-plan
description: Generate a manual QA verification plan for a Jira task, bug, or epic by reviewing the work item context and the related branch diff. Use when implementation already exists and you want tester-friendly verification steps covering prerequisites, expected results, regressions, and edge cases, then append the final QA plan to the Jira issue description.
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_update_issue
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this manual QA planning target is: $ARGUMENTS

Execute all phases in strict sequential order (Q0-Q4). Do not skip, reorder, or combine any phases. Stop and report in the chat if any phase fails.
