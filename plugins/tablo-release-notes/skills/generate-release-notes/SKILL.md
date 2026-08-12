---
name: generate-release-notes
description: Generate release notes for a Tablo client-app build — gathers Jira fix-version tickets and GitLab MRs/commits, drafts customer-facing notes and an internal companion doc, and publishes both to Confluence. Supports prerelease builds. Invoke with the build version, e.g. `/generate-release-notes 2.2-alpha.1`.
user-invocable: true
argument-hint: '<version, e.g. 2.2, 2.2-alpha.1, 2.2-beta.2, 2.2-final>'
allowed-tools: Agent, Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Skill
model: opus
effort: max
disable-model-invocation: true
---

Read ./workflow.md in this skill directory for the full execution contract, then follow it exactly. The release version is: $ARGUMENTS
