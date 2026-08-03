---
name: project-onboarding
description: Onboard a project for AI-agent use by generating or enhancing README.md, CONTRIBUTING.md, CONTEXT.md, CLAUDE.md, and WORKFLOWS.md — plus a cross-agent AGENTS.md pointer, mermaid diagrams in CONTEXT.md, and short nested per-module docs. Use when setting up a codebase so AI agents can contribute effectively, or when these docs are missing, incomplete, or stale and need refreshing. Thoroughly investigates the codebase, auto-detects conventions and commands, asks the user only what it cannot infer (branch naming, Jira spaces, review process, deploy flow), then writes the docs into the project. Runs in initial mode on a bare project and refresh mode on one that already has the docs. Drives the complete O0-O6 process.
user-invocable: true
argument-hint: "[target-path]"
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_web-cms_sequentialthinking__sequentialthinking, mcp__plugin_web-cms_serena__onboarding, mcp__plugin_web-cms_serena__list_memories, mcp__plugin_web-cms_serena__read_memory, mcp__plugin_web-cms_atlassian__jira_get_all_projects
model: opus
effort: high
---

Read `./workflow.md` in this skill directory for the full execution contract, then follow it exactly.

The optional target path is: $ARGUMENTS

If `$ARGUMENTS` contains a path, treat it as the project to onboard; otherwise use the current working directory. Either way the skill resolves the project's git worktree root and writes the five documentation files (`README.md`, `CONTRIBUTING.md`, `CONTEXT.md`, `CLAUDE.md`, `WORKFLOWS.md`) into that root, along with a thin cross-agent `AGENTS.md` (pointing to `CLAUDE.md`), mermaid diagrams embedded in `CONTEXT.md`, and short nested per-module docs in large subdirectories.

At O0 the skill detects **mode**: *initial* (few or none of the five files exist — full generation) or *refresh* (all/most exist — reconcile against the current codebase, flag drift, preserve human-authored content, update only what changed).

Execute all phases in strict sequential order (O0-O6). Do not skip, reorder, or combine any phases. All approval gates require explicit confirmation before proceeding, and no documentation file is written until the O4 outline/drift gate is approved.
