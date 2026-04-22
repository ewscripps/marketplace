# DOCUMENTATION WORKFLOW -- EXECUTION CONTRACT

**STRICT EXECUTION RULES -- NO EXCEPTIONS:**

1. Execute phases in strict sequential order (D0 through D8).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest documentation plan or draft and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (D0–D1): Understand completed work, identify documentation scope
- **Planning** (D2–D3): Documentation plan, approval
- **Drafting** (D4–D6): Write drafts, review, revise
- **Completion** (D7–D8): Publish, summary

---

### D0 -- Understand the Completed Work

**Objective:** Read the completed Jira work item and extract everything needed to write user-facing documentation.

**Agent Actions:**

1. Retrieve the Jira issue using the provided key. Read its full description.
2. Determine the work type by examining the issue type and description structure:
    - **Task / Epic:** Look for `## Task Details` and the summary of changes comment (T12 or E10).
    - **Bug:** Look for `## Bug Details` and the summary of changes comment (B14).
    - **Unsupported issue types (including Code Review):** Stop and explain that this workflow only supports completed Task, Epic, and Bug cards unless it is explicitly extended.
3. Read the **most recent summary comment** on the issue (the T12, E10, or B14 output). This contains: what was done, files changed, deviations from plan, and QA verification steps.
4. Identify the **user-facing changes** -- what a user of the application would notice or need to learn. Filter out purely internal changes (refactors, internal API changes, infrastructure) unless the user explicitly asks for them to be documented.
5. Classify the documentation scope:
    - **UI changes** -- New or modified screens, forms, buttons, workflows, navigation, or visual elements that users interact with.
    - **API changes** -- New or modified HTTP endpoints, request/response formats, authentication, or integration points.
    - **Both** -- Changes that span UI and API.
    - **Neither** -- Purely internal changes with no user-facing impact. If this is the case, inform the user and ask whether to proceed with internal/developer documentation or stop.

> **REQUIRED:** Present all of the following in the chat before proceeding:
>
> - Work item type (Task / Epic / Bug) and title
> - Summary of what was implemented or fixed
> - User-facing changes identified (UI, API, or both)
> - Documentation scope classification
> - Any changes that were excluded as purely internal, with reasoning

---

### D1 -- Gather Documentation Context

**Objective:** Collect all environment details and access prerequisites needed to capture documentation without exposing credentials in chat.

**Ask the following questions conversationally, one topic at a time. Wait for each response before asking the next.**

**Environment:**

1. What is the **staging environment URL** where the changes can be tested?
2. Does the staging environment require **authentication**?
    - If yes: What type -- **Okta**, **basic auth**, or **other**?
    - Is a secure authenticated session already available to the agent, or will you pre-authenticate before D3? **Do not provide passwords, tokens, or secrets in chat.**
3. After authentication is available, are there any additional navigation steps to reach the area where the changes are visible (e.g., specific menu path, feature flag to enable, test account to use)?

**API documentation (if scope includes API changes):**

4. What is the **Postman workspace URL** (e.g., `app.getpostman.com/workspace/...`)?
5. Does Postman require separate authentication? If yes, is a secure authenticated session already available, or will you pre-authenticate before D3? **Do not provide passwords, tokens, or secrets in chat.**
6. Is there an existing **Postman collection** this should be added to, or should a new collection be created?

**Confluence target:**

7. What **Confluence space** should the documentation be published to?
8. Is there a **parent page** the documentation should be nested under? If yes, what is the page title or URL?

**Scope refinement:**

9. Are there **specific user flows or scenarios** you want prioritized in the documentation?
10. Is there a **target audience** for this documentation (end users, internal staff, developers, QA)?

> **REQUIRED:** The following context must be confirmed before proceeding:
>
> - Staging URL
> - Authentication method and how access will be provided (existing session, user pre-authentication, environment-provided secret, or "none required")
> - Navigation instructions (or "none -- changes are immediately visible")
> - Postman details (if API scope): workspace URL, collection, and how authenticated access will be provided
> - Confluence space and parent page
> - Priority scenarios (or "document all user-facing changes")
> - Target audience

> **APPROVAL GATE -- FULL STOP.** Present the gathered context as a structured summary. User must confirm all fields are accurate. Do not proceed to D2 until confirmed.

---

### D2 -- Plan Documentation

> **USE SEQUENTIAL THINKING:** Before producing the plan, invoke the `sequentialthinking` tool. Work through each user-facing change identified in D0, determine which ones warrant step-by-step documentation, identify the optimal order for capturing screenshots (to minimize navigation), and verify that every change is accounted for in the plan.

**Objective:** Create a documentation plan that defines exactly what will be captured and how the Confluence page will be structured.

**Agent Actions:**

1. For each user-facing change, determine the documentation approach:

    **UI changes -- plan the user flows:**
    - Define each flow as a sequence of numbered steps
    - For each step: describe the action the user takes and the expected result
    - Mark which steps need a screenshot (default: every step that changes what the user sees)
    - Order flows to minimize redundant navigation (e.g., if two flows start from the same page, capture them back-to-back)

    **API changes -- plan the endpoint documentation:**
    - List each endpoint: method, path, purpose
    - Define the request example (headers, body, query params)
    - Define the expected response
    - Note any authentication requirements specific to the endpoint

2. Draft the **Confluence page outline:**

    ```
    # [Feature/Change Name]

    ## Overview
    [What changed and why -- 2-3 sentences from the Jira context]

    ## Prerequisites
    [What the user needs before using this feature -- permissions, configuration, etc.]

    ## [Flow Name 1]
    ### Step 1: [Action]
    [Description + screenshot]
    ### Step 2: [Action]
    [Description + screenshot]
    ...

    ## [Flow Name 2]  (if multiple flows)
    ...

    ## API Reference  (if API changes)
    ### [Endpoint Name]
    [Method, path, description, request/response examples, Postman screenshot]
    ...

    ## Tips and Notes
    [Edge cases, common questions, related features]

    ## Related
    [Link to Jira issue]
    ```

3. Present the full plan: list of flows with steps, list of API endpoints, and the page outline.

> **REQUIRED:** Present all of the following in the chat before proceeding:
>
> - Numbered list of UI flows with steps and screenshot markers
> - List of API endpoints to document (if applicable)
> - Confluence page outline
> - Estimated number of screenshots

> **APPROVAL GATE -- FULL STOP.** Present the documentation plan. User must confirm the flows, endpoints, and page structure are correct. Do not proceed to D3 until confirmed.

---

### D3 -- Set Up Environment & Authenticate

**Objective:** Open the browser, navigate to the staging environment, authenticate, and verify access.

**Agent Actions:**

**UI setup (if scope includes UI changes):**

1. Navigate to the staging URL provided in D1 using `browser_navigate`.
2. If authentication is required:
    - Reuse an existing authenticated browser session or environment-provided secret if one is securely available to the runtime.
    - Never ask the user to paste usernames, passwords, tokens, or other secrets into chat.
    - If authentication is required but no secure session or environment-provided secret is available, stop and ask the user to complete authentication out of band before proceeding.
3. Use `browser_snapshot` to confirm the application has loaded successfully after authentication.
4. If additional navigation is needed to reach the feature area (as noted in D1), navigate there now.
5. Take a baseline screenshot using `browser_take_screenshot` to confirm the environment is ready. Save it as `00-baseline.png`.

**API setup (if scope includes API changes):**

6. Open a new tab or navigate to the Postman workspace URL provided in D1.
7. Reuse an existing authenticated Postman session or environment-provided secret if required. If secure access is not available, stop and ask the user to authenticate out of band before proceeding.
8. Navigate to the target collection (or create a new one if specified in D1).
9. Use `browser_snapshot` to confirm Postman is ready.

> **REQUIRED:** Confirm in the chat that the environment is accessible and authenticated. If authentication fails, stop and report the specific failure. Do not proceed with incorrect or missing access.

---

### D4 -- Capture UI Documentation

> **Skip this phase entirely if the documentation scope is API-only.**

**Objective:** Walk through each user flow from the D2 plan, take screenshots at each step, and record the step descriptions.

**Agent Actions:**

For each flow in the documentation plan, in the order defined in D2:

1. Navigate to the starting point of the flow.
2. Use `browser_snapshot` to confirm you are on the correct page.
3. For each step in the flow:
    a. **Take a "before" screenshot** (if the step involves a state change) using `browser_take_screenshot`. Save with a descriptive filename: `{flow-number}-{step-number}-{short-description}.png` (e.g., `01-02-click-save-button.png`).
    b. **Perform the action** described in the step (click, type, select, navigate) using the appropriate browser tool (`browser_click`, `browser_type`, `browser_fill_form`, `browser_select_option`, `browser_press_key`).
    c. **Wait for the result** using `browser_wait_for` if needed (e.g., wait for a loading spinner to disappear, a success message to appear, or a page to load).
    d. **Take an "after" screenshot** showing the result of the action. Save with a descriptive filename.
    e. **Record the step description**: what the user does, what they see, and any important details about the result.
4. After completing all steps in a flow, confirm the flow was captured successfully.
5. If a step fails (element not found, unexpected page state), stop the current flow, take a screenshot of the current state, and report the failure in the chat. Ask the user whether to retry, skip the flow, or stop.

> **REQUIRED:** After all flows are captured, present a summary in the chat:
>
> - List of flows captured with step counts
> - Total screenshots taken
> - Any flows that failed or were skipped, with reasons

---

### D5 -- Capture API Documentation

> **Skip this phase entirely if the documentation scope is UI-only.**

**Objective:** Document each API endpoint in Postman and capture screenshots of requests and responses.

**Agent Actions:**

For each endpoint in the documentation plan, in the order defined in D2:

1. In Postman, create a new request in the target collection (or navigate to an existing one if updating).
2. Set the request method, URL, headers, and body as defined in the plan.
3. Use `browser_snapshot` to verify the request is configured correctly.
4. Take a screenshot of the request configuration using `browser_take_screenshot`. Save as `api-{endpoint-number}-request-{short-name}.png`.
5. Execute the request (click Send).
6. Wait for the response to appear.
7. Take a screenshot of the response using `browser_take_screenshot`. Save as `api-{endpoint-number}-response-{short-name}.png`.
8. Record the endpoint documentation: method, path, description, request example, response example, status code, and any notes.
9. If the request fails unexpectedly, take a screenshot of the error response, report it in the chat, and ask the user whether to retry, skip, or stop.

**Save the collection:**

10. After all endpoints are documented, save the Postman collection.
11. Take a final screenshot of the collection overview showing all documented endpoints.

> **REQUIRED:** After all endpoints are captured, present a summary in the chat:
>
> - List of endpoints documented
> - Total screenshots taken
> - Any endpoints that failed or were skipped, with reasons

---

### D6 -- Assemble Confluence Page

> **USE SEQUENTIAL THINKING:** Before generating the page content, invoke the `sequentialthinking` tool. Verify that every flow and endpoint from the D2 plan is represented, that screenshots are referenced in the correct order, and that the page reads coherently from a user's perspective.

**Objective:** Assemble the full Confluence page content from the captured documentation.

**Agent Actions:**

1. Build the page content using the outline from D2, populated with:

    - **Overview:** Derived from the Jira issue description and summary comment. Written for the target audience identified in D1 -- not developer jargon unless the audience is developers.
    - **Prerequisites:** Permissions, configuration, or setup the user needs. Derived from the Jira card context and any authentication requirements observed during capture.
    - **UI flow sections:** For each flow, convert the captured steps into clear, numbered instructions. Reference the screenshot filename for each step -- these will be embedded after upload.
    - **API reference section:** For each endpoint, include: method, path, description, request example (formatted as a code block), response example (formatted as a code block), and a reference to the Postman screenshots.
    - **Tips and Notes:** Edge cases, common questions, or important details observed during capture.
    - **Related:** Link to the Jira issue key.

2. Write the page content in **Confluence storage format** (XHTML). Use these elements:
    - Headings: `<h1>`, `<h2>`, `<h3>`
    - Paragraphs: `<p>`
    - Ordered lists: `<ol><li>`
    - Code blocks: `<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>`
    - Image attachments: `<ac:image ac:width="800"><ri:attachment ri:filename="screenshot-name.png" /></ac:image>`
    - Info panels: `<ac:structured-macro ac:name="info"><ac:rich-text-body><p>...</p></ac:rich-text-body></ac:structured-macro>`
    - Jira issue link: `<ac:structured-macro ac:name="jira"><ac:parameter ac:name="key">PROJ-123</ac:parameter></ac:structured-macro>`

3. Present the full page content in the chat (rendered as markdown for readability, noting that the actual Confluence content will use storage format).

> **REQUIRED:** Present the full documentation draft in the chat. Include:
>
> - The complete page content (in readable markdown form)
> - A list of all screenshots that will be attached, in order
> - The target Confluence space and parent page

---

### D7 -- Review Documentation

---

**APPROVAL GATE -- FULL STOP.**

- Present the full documentation draft assembled in D6.
- The user must review and confirm the content is accurate, complete, and appropriate for the target audience.
- If the user requests changes, revise the content and re-present. Do not proceed until explicit approval.
- If the user identifies missing flows or screenshots, return to D4 or D5 to capture the additional content, then reassemble in D6 and re-present here.

---

### D8 -- Publish to Confluence

**Objective:** Create the Confluence page, upload all screenshots, and link the documentation to the Jira issue.

**Agent Actions:**

1. **Look up the parent page.** Use `confluence_search` or `confluence_get_page` to find the parent page specified in D1 and retrieve its ID.

2. **Create the Confluence page.** Call `confluence_create_page` with:
    - The Confluence space key from D1
    - The page title (derived from the work item title, e.g., "How to [Feature Name]" or "[Feature Name] Documentation")
    - The parent page ID
    - The page body in Confluence storage format from D6

3. **Upload screenshots.** For each screenshot captured in D4 and D5, call `confluence_upload_attachment` to upload the image file to the newly created page. Use `confluence_upload_attachments` for batch upload if supported.

4. **Verify the page.** Call `confluence_get_page` to confirm the page was created successfully and all attachments are present.

5. **Add labels.** Call `confluence_add_label` to tag the page with relevant labels (e.g., the Jira project key, `documentation`, the work type).

6. **Link to Jira.** Post a comment on the Jira issue using `jira_add_comment` with a link to the newly created Confluence page. Format:

    ```
    Documentation published: [Page Title]
    Confluence page: [URL]

    This page documents the user-facing changes implemented in this work item.
    ```

7. **Close the browser.** Call `browser_close` to clean up the browser session.

> **REQUIRED:** Present all of the following in the chat:
>
> - Confluence page URL
> - Confirmation that all screenshots were uploaded
> - Confirmation that the Jira issue was updated with the documentation link
> - Any issues encountered during publishing

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (D0-D8)
- All approval gates explicitly confirmed in the chat
- Confluence page created with all content and screenshots
- Jira issue updated with a link to the documentation
- Browser session closed
