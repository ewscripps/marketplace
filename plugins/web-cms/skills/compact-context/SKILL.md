---
name: compact-context
description: Manually trigger a context compaction checkpoint during any active web-cms workflow session. Reads the active work item's current checkpoint, overwrites its checkpoint.md to capture the current phase position, and prompts the user to run /compact. Use at any point mid-workflow when context is growing full and the workflow is between designated compaction gates.
user-invocable: true
argument-hint: ""
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
model: sonnet
effort: low
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

Execute phases C0 through C3 in strict sequential order. Stop immediately if no active session is found in C0.
