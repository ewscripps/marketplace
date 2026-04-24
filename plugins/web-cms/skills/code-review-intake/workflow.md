# CODE REVIEW INTAKE WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow by asking the agent to set up a code review. The agent drives the entire process interactively — gathering review context through conversation, verifying the Jira issue and branch exist, asking targeted clarifying questions, then creating a fully populated Jira Code Review issue with the Review Details section pre-filled. The card contains only structured review context; execution happens when the user invokes the separate `/code-review` skill.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (CI0 through CI5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until CI5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat — no Jira issue exists yet.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest review setup or draft and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Intake** (CI0–CI1): Gather review context, Jira context review
- **Verification** (CI2–CI3): Branch verification, clarifying questions
- **Creation** (CI4–CI5): Assemble Review Details, Jira issue creation/update

---

### CI0 — Intake

**Objective:** Greet the user and gather all context needed to set up the code review through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, approvals, end result).
    
2. Ask the following **first two questions** and wait for the responses before continuing:
    
    - What type of work is being reviewed? _(Release / Epic / Task / Bug)_
    - Is this a **diff review** (reviewing changes between branches) or an **implementation review** (deep dive into an existing implementation without diffing branches)?
3. Based on the answers, continue gathering context **conversationally, one topic at a time.**
    
    **All review types:**
    
    - What branch contains the work to be reviewed?
    - **Diff Review only:** What is the default branch to diff against? (e.g., main, master, develop)
    - **Implementation Review only:** What is the implementation scope? (List the files, modules, or services to review.)
    - What are the goals of this review — what should the reviewer verify or pay particular attention to?
    - Are there any known risks or areas of concern the reviewer should focus on?
    - Has a Jira card already been created for this code review? If so, what's the issue key?
    
    **Release only (ask instead of Jira issue key):**
    
    - What is the name of the release? (e.g., v2.4.0, Q2 Release, Sprint 42)
    - What Jira project does this release belong to? (e.g., PROJ)
    
    **Epic, Task, and Bug only:**
    
    - What is the Jira issue key for the item being reviewed? (e.g., PROJ-123)
4. After all questions are answered, summarize the gathered context back to the user.
    

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Review Type (Release / Epic / Task / Bug)
> - Review Mode (Diff / Implementation)
> - Release Name + Project Key (Release only), or Jira Issue Key (Epic / Task / Bug)
> - Branch to Review
> - Default Branch (Diff Review only)
> - Implementation Scope (Implementation Review only)
> - Review Goals
> - Known Risks or Areas of Concern (description, or explicitly "none identified")
> - Existing Jira Card for this review (issue key, or explicitly "none")

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. User must confirm all fields are accurate. Do not proceed to CI1 until confirmed.

---

### CI1 — Jira Context Review

**Objective:** Retrieve the review target and all associated work items from Jira automatically. If an existing code review card was provided, retrieve and surface its context.

**Agent Actions:**

1. If an Existing Jira Card key was provided in CI0, retrieve that issue immediately. Read its full description, summary, and any context already captured. Surface all of this content — it will be used to enrich the final Review Details in CI4.
    
2. Based on the Review Type, retrieve the review target and its work items:
    
    **Release:**
    
    - Search Jira for the release by name within the specified project. Confirm the release exists.
    - Retrieve all issues associated with the release using JQL: `project = [PROJECT KEY] AND fixVersion = "[RELEASE NAME]"`.
    - For each issue retrieved, read its description and acceptance criteria. Flag any missing acceptance criteria.
    - Confirm the release status is appropriate to be reviewed.
    - Recover the most recent branch name for each included work item from its latest testing handoff or summary comment when available. Note any missing branch names for CI2.
    
    **Epic:**
    
    - Retrieve the Jira issue provided in CI0 and confirm it is an Epic.
    - Read the epic description, goals, and acceptance criteria fully, including comment history.
    - Retrieve all child issues using JQL: `parent = [EPIC KEY]`.
    - For each child issue, read its description and acceptance criteria. Flag any missing acceptance criteria.
    - Recover the most recent branch name for each child issue from its latest testing handoff or summary comment when available. Note any missing branch names for CI2.
    
    **Task:**
    
    - Retrieve the Jira issue and confirm it is a Task.
    - Read the task description, acceptance criteria, affected areas, and approved implementation plan from comment history.
    
    **Bug:**
    
    - Retrieve the Jira issue and confirm it is a Bug.
    - Read the bug description, fix criteria, steps to reproduce, affected areas, and approved fix plan from comment history.
    - Note any regression tests required as part of the fix.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - If an existing code review card was provided: its full summary, description, and captured context
> - Release/Epic: full list of retrieved work items (key, summary, status), flagging any with missing acceptance criteria
> - Release/Epic: recovered work item branch names, flagging any missing branch context needed for CI2
> - Task/Bug: confirmation the issue exists and matches the stated Review Type
> - Summary of the target: title or name, status, key details relevant to the review
> - Any concerns about issue state that the user should be aware of

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. User must confirm the retrieved issue or release is correct, the work item list (Release/Epic) is complete and accurate, and no concerns block the review from proceeding. Do not proceed to CI2 until confirmed.

---

### CI2 — Branch Verification

**Objective:** Confirm the branch to review exists and is in a reviewable state before investing time in the full intake.

**Agent Actions:**

**Diff Review:**

1. Confirm the branch provided in CI0 exists in the repository.
2. Confirm the default branch provided in CI0 exists.
3. Confirm the branch to review has commits beyond the default branch.
4. **Release and Epic only:** Using the branch names recovered in CI1 (plus any explicitly provided by the user), confirm that all work item branches are merged into the branch to review. If any required branch name is missing, stop and ask the user to provide it before continuing. List any recovered branches that are missing.
5. If any check fails, stop and report the specific failure. Do not proceed until the user resolves the issue.

**Implementation Review:**

1. Confirm the branch provided in CI0 exists in the repository and can be checked out.
2. Confirm the files, modules, or services listed in the Implementation Scope exist on the branch. List any that are missing or have been renamed.
3. If any check fails, stop and report the specific failure. Do not proceed until the user resolves the issue.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> **Diff Review:**
> - Confirmation the branch to review exists
> - Confirmation the default branch exists
> - Confirmation there are commits to review
> - Release/Epic only: confirmation all work item branches are merged, or list of missing branches and any unresolved branch-name gaps
>
> **Implementation Review:**
> - Confirmation the branch to review exists
> - Confirmation that all scoped files/modules/services exist on the branch, or list of missing items

> **APPROVAL GATE — FULL STOP.** Present the branch verification summary. User must confirm branch state is correct and ready for review, and any missing branches or scoped items (if applicable) are resolved or intentionally excluded. Do not proceed to CI3 until confirmed.

---

### CI3 — Clarifying Questions

**Objective:** Surface any remaining ambiguities that would affect the scope or depth of the review.

**Agent Actions:**

1. Review all output from CI0, CI1, and CI2.
    
2. Generate clarifying questions using the categories relevant to the review type:
    
    **All review types:**
    
    - **Scope** — Are there any files, modules, or areas that should be explicitly excluded?
    - **Standards** — Are there any project-specific standards the reviewer should apply beyond defaults?
    - **Focus** — Are there specific review categories that should be weighted more heavily?
    
    **Release only:**
    
    - **Readiness** — Are all work items confirmed complete and merged, or are any still in progress?
    - **Deployment** — Are there any environment-specific concerns the reviewer should be aware of?
    
    **Epic only:**
    
    - **Integration** — Are there known integration points between child tasks that warrant extra scrutiny?
    - **Scope Drift** — Did any child tasks expand beyond the original epic breakdown plan?
    
    **Task only:**
    
    - **Plan Deviations** — Are there any known deviations from the approved implementation plan?
    
    **Bug only:**
    
    - **Regression Risk** — Are there related behaviors or code paths beyond the direct fix that should be verified?
    - **Test Coverage** — Was a regression test written? If not, is one expected as part of this review?
3. Mark each question as `[BLOCKING]` or `[NICE TO HAVE]`.
    
4. Present all questions in a **single batch** — do not ask one at a time.
    
5. Record all answers verbatim.
    

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate. Do not proceed to CI4 until confirmed.

---

### CI4 — Review Setup

**Objective:** Assemble the fully populated Review Details that will be written into the Jira issue description.

**Agent Actions:**

1. Using all output from CI0–CI3, including any context from the existing code review card retrieved in CI1, assemble the complete Review Details block:

**Diff Review:**

```
## Review Details

**Review Type:** [Release / Epic / Task / Bug — from CI0]

**Review Mode:** Diff

**Release Name** (Release only): [release name — omit for Epic, Task, Bug]

**Jira Issue Key** (Epic / Task / Bug only): [from CI0 — omit for Release]

**Branch to Review:** [from CI0, confirmed in CI2]

**Default Branch:** [from CI0, confirmed in CI2]

**Review Goals:** [from CI0, expanded with relevant context from CI1 and CI3,
including any goals already captured on the existing code review card if applicable]

**Work Items Included** (Release and Epic only):
[Auto-retrieved from Jira in CI1 — list each item as: KEY — Summary (Status).
Omit this field for Task and Bug reviews.]

**Known Risks or Areas of Concern:**
[From CI0 and CI3 — consolidated into a clear list. Or "None identified".]
```

**Implementation Review:**

```
## Review Details

**Review Type:** [Release / Epic / Task / Bug — from CI0]

**Review Mode:** Implementation

**Release Name** (Release only): [release name — omit for Epic, Task, Bug]

**Jira Issue Key** (Epic / Task / Bug only): [from CI0 — omit for Release]

**Branch to Review:** [from CI0, confirmed in CI2]

**Implementation Scope:**
[List of files, modules, or services to review — from CI0, confirmed in CI2]

**Review Goals:** [from CI0, expanded with relevant context from CI1 and CI3,
including any goals already captured on the existing code review card if applicable]

**Work Items Included** (Release and Epic only):
[Auto-retrieved from Jira in CI1 — list each item as: KEY — Summary (Status).
Omit this field for Task and Bug reviews.]

**Known Risks or Areas of Concern:**
[From CI0 and CI3 — consolidated into a clear list. Or "None identified".]
```

2. Review the assembled block for completeness and accuracy before presenting.

> **REQUIRED: Review the assembled Review Details before presenting.** Verify all fields are populated, the work items are complete and match CI1 output, and known risks consolidate all concerns surfaced across CI0–CI3.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled Review Details. User must confirm all fields are accurate and nothing is missing. Do not proceed to CI5 until confirmed.

---

### CI5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira code review card with the confirmed Review Details.

**Agent Actions:**

1. Construct the Jira issue description using the confirmed Review Details from CI4 only. Do not append workflow instructions, skill-invocation text, or placeholder tokens:

```
[Review Details from CI4 -- copy verbatim]
```

2. Populate the following fields:

|Field|Source|
|---|---|
|Issue Type|Task|
|Summary|`Code Review: [Review Type] -- [Release Name or Issue Key]`|
|Description|Assembled per above|
|Priority|Recommended based on review scope and risk (see below)|
|Labels|`code-review` + review type in lowercase|
|Epic Link|Recommended epic (see below)|

    **Priority recommendation:** Before creating the issue, recommend a priority based on the review scope and risk: Release reviews default to High, Epic reviews default to Medium, Task/Bug reviews default to the priority of the reviewed issue (or Medium if unknown). Present the recommended priority to the user for confirmation.

    **Epic recommendation:** Search Jira for open epics in the same project that relate to the code areas or issues being reviewed. If the reviewed issue is already linked to an epic, suggest that epic. Present the recommendation and ask the user to: (a) accept the suggested epic, (b) provide a different epic key, or (c) leave blank for no epic. Only set the Epic Link if the user accepts or provides a key.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "Medium"}}` (substituting the confirmed priority name: Critical, High, Medium, or Low).
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `createJiraIssue`. Do not use `createIssueLink` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.
    - **Labels:** Set via `additional_fields`: `{"labels": ["code-review", "reviewtype"]}` on `createJiraIssue`.

3. **Update-or-create decision:**
    - **If an existing Jira card was provided in CI0:** Update that card's description using `editJiraIssue` with the approved Review Details. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira issue using `createJiraIssue` with the approved Review Details. Do not perform a follow-up description update solely to add execution instructions.

4. **Post-creation linking (Epic / Task / Bug only):** After the issue is created, link it to the Jira issue being reviewed by calling `createIssueLink` with `link_type: "Relates to"`, `inward_issue_key` set to the new review issue's key, and `outward_issue_key` set to the reviewed issue's key. Do not attempt to set linked issues during `createJiraIssue` — that tool does not support it.

> **REQUIRED: Review the full issue description before presenting.** Verify Review Details section exactly matches CI4 output verbatim, no workflow instructions or skill-invocation text were embedded, the summary follows the specified format, the issue type is set to Task, and the linked issue is correct (Epic / Task / Bug only).

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description. User must confirm content is accurate before creating or updating the Jira issue.

**Post-creation: Additional Linking** After the Jira issue has been created or updated, ask: "Is there any additional Jira issue this review should be linked to? If yes, provide the issue key."

If the user provides a key, call `getJiraIssue` to confirm it exists, then call `createIssueLink` with `link_type: "Relates to"` to create the link. Confirm success. If the user provides no key, skip this step.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 6 phases executed in sequence (CI0-CI5)
- All 6 approval gates explicitly confirmed in the chat
- All self-review checks passed before presenting output
- Jira Code Review issue updated or created with Review Details fully populated, no unresolved placeholder text, and no embedded workflow or skill-invocation instructions
- Review target linked to the Code Review issue (Epic / Task / Bug only)
