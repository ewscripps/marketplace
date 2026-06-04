---
name: requirements-intake
description: Execute the Requirements Intake workflow to define a new feature or maintenance item. Use when starting a new piece of work that needs to be formally defined, OR when an existing Jira task or epic needs its description fleshed out. Invoke without arguments to create a new card; invoke with a Jira key (e.g. /requirements-intake PROJ-123) to fill out an existing card and, if it's an epic, its child tasks too. Drives the complete R0-R6 process including stakeholder Q&A, codebase analysis, acceptance criteria, and Jira issue creation or update.
user-invocable: true
argument-hint: "[jira-key]"
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_search, mcp__plugin_web-cms_atlassian__jira_create_issue, mcp__plugin_web-cms_atlassian__jira_update_issue, mcp__plugin_web-cms_atlassian__jira_create_issue_link, mcp__plugin_web-cms_memory__read_graph, mcp__plugin_web-cms_memory__create_entities, mcp__plugin_web-cms_memory__create_relations, mcp__plugin_web-cms_memory__add_observations, mcp__plugin_web-cms_memory__delete_entities
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The optional Jira issue key is: $ARGUMENTS

If $ARGUMENTS contains a Jira issue key (matches `[A-Z][A-Z0-9_]+-\d+`), enter **fill-out mode**: flesh out the description of that existing card. If the card is an Epic with child tasks, also iterate each child interactively after fleshing the epic. If $ARGUMENTS is empty, enter **define mode** and run the normal workflow to create a new card.

Execute all phases in strict sequential order (R0-R6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
