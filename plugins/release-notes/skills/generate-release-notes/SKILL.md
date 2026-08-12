---
name: generate-release-notes
description: Generate release notes for a product version — gathers Jira fix-version tickets and GitLab MRs/commits, drafts customer-facing notes and an internal companion doc, publishes to Confluence, and drops a formatted email.html in the configured OneDrive folder. Invoke with the version string, e.g. `/generate-release-notes 2.8.0`.
user-invocable: true
argument-hint: '<version, e.g. 2.8.0>'
allowed-tools: Agent, Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Skill
model: opus
effort: max
disable-model-invocation: true
---

Read ./workflow.md in this skill directory for the full execution contract, then follow it exactly. The release version is: $ARGUMENTS
