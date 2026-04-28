---
name: test-doc-review
description: Execute an independent test and documentation review for a Jira task or bug issue, or for the current repository state without Jira context. Use when implementation is complete and dedicated test and documentation coverage is needed outside the main task or bug workflow — invoke with an optional Jira issue key or without arguments for repository-only review. Handles the complete TD0-TD5 lifecycle including optional issue discovery, diff gathering, context assembly, test review, documentation review, and a final summary.
user-invocable: true
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__plugin_web-cms_atlassian__jira_get_issue
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Optional Jira issue key for this work item: $ARGUMENTS

If no Jira issue key is provided, skip TD0 and begin at TD1 using repository-only context.

Execute all phases in strict sequential order (TD0-TD5), with TD0 skipped only when no Jira issue key is provided. Do not skip, reorder, or combine any other phases. Stop and report in the chat if any phase fails.
