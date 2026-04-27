---
name: document-card
description: Generate user-facing documentation for a completed Jira task, epic, or bug. Reads the completed work item, uses Playwright to capture UI flows with screenshots in a staging environment, documents API changes in Postman, and publishes the result to a Confluence page.
argument-hint: "[PROJ-123]"
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_atlassian__jira_get_issue, mcp__plugin_web-cms_atlassian__jira_add_comment, mcp__plugin_web-cms_playwright__browser_navigate, mcp__plugin_web-cms_playwright__browser_snapshot, mcp__plugin_web-cms_playwright__browser_take_screenshot, mcp__plugin_web-cms_playwright__browser_click, mcp__plugin_web-cms_playwright__browser_type, mcp__plugin_web-cms_playwright__browser_fill_form, mcp__plugin_web-cms_playwright__browser_select_option, mcp__plugin_web-cms_playwright__browser_press_key, mcp__plugin_web-cms_playwright__browser_wait_for, mcp__plugin_web-cms_playwright__browser_tabs, mcp__plugin_web-cms_playwright__browser_close, mcp__plugin_web-cms_atlassian__confluence_search, mcp__plugin_web-cms_atlassian__confluence_get_page, mcp__plugin_web-cms_atlassian__confluence_create_page, mcp__plugin_web-cms_atlassian__confluence_get_attachments, mcp__plugin_web-cms_atlassian__confluence_upload_attachment, mcp__plugin_web-cms_atlassian__confluence_upload_attachments, mcp__plugin_web-cms_atlassian__confluence_add_label
model: sonnet
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The Jira issue key for this work item is: $ARGUMENTS

Execute all phases in strict sequential order (D0-D8). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding.
