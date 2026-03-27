---
name: edm-srd-audit
description: "EDM Phase 3: Audit an SRD for feature gaps, factual errors, diagram issues, competing requirements, reuse opportunities, and spec quality. Use after SRD creation to catch errors before they propagate to tickets and code."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - srd
  - audit
  - review
  - quality
author: Scripps MCP
---

# EDM Phase 3: SRD Audit

## Overview

The SRD audit is the highest-leverage phase. Every error caught here saves 10x the effort of catching it during implementation. This phase systematically reviews the SRD across 7 audit categories.

- **Input**: SRD from Phase 2
- **Output**: Audit report with categorized findings and severity levels

## Audit Categories

Check the SRD against ALL 7 categories:

### 1. Feature Gaps
- Missing requirements
- Unaddressed edge cases
- Parity gaps with existing systems
- User flows that dead-end

### 2. Factual Mistakes
- Wrong API names or endpoints
- Incorrect library references
- Impossible claims about tools or platforms
- Version mismatches

### 3. Diagram Errors
- Syntax errors (Mermaid/PlantUML won't render)
- Logical flow errors
- Missing edges or orphan nodes
- Unlabeled connections

### 4. Competing Requirements
- Conflicts with current codebase behavior
- Conflicts with existing features
- Conflicts with other specs or platform limitations
- Internal contradictions within the SRD

### 5. Reuse Opportunities
- Existing code that should be leveraged
- Libraries already in the dependency tree
- Services or patterns that exist but aren't referenced
- Shared utilities being rebuilt unnecessarily

### 6. Specification Quality
- Untestable requirements (vague language)
- Missing requirement IDs
- Internal contradictions
- Missing priorities (Must/Should/Could)

### 7. Additional Concerns
- Licensing issues
- Accessibility gaps
- Internationalization needs
- Backward compatibility risks
- Deployment impact
- Team skills gaps

## Severity Levels

| Severity | Definition | Action |
|----------|-----------|--------|
| **P0** | Blocks implementation, creates security/legal issue, or is architecturally wrong | Must fix before moving to Phase 4 |
| **P1** | Significant gap, factual error, or missing requirement | Must fix before moving to Phase 4 |
| **P2** | Polish issue, edge case, or improvement | Can defer to Ticket Pack or Implementation |

## Finding Format

Each finding MUST follow this structure:

```
[CATEGORY] [SEVERITY] Section X.Y | Specific finding | Recommendation
```

### Examples

```
[FEATURE GAP] [P1] Section 6.2 | No requirement for credential expiration
while user is offline | Add requirement with max offline TTL and re-auth flow

[FACTUAL] [P0] Section 7.3 | Claims library X supports feature Y, but it
does not as of v3.2 | Replace with library Z or implement custom solution

[REUSE] [P2] Section 8.1 | Describes building a new retry mechanism, but
shared/retry module already implements exponential backoff | Reference existing module

[DIAGRAM] [P1] Section 5.1 | Mermaid flowchart has syntax error on line 12,
missing arrow between AuthService and TokenStore | Fix arrow syntax

[COMPETING] [P1] Section 6.4 | Requires JWT tokens in cookies, but Section 6.8
requires token in Authorization header | Resolve which approach, or document both

[SPEC QUALITY] [P2] Section 6.10 | Requirement AUTH-15 says "should be fast"
without measurable criteria | Replace with "< 100ms p95 at 500 QPS"

[ADDITIONAL] [P1] Section 9.0 | No consideration for WCAG 2.1 AA accessibility
on the new login form | Add accessibility requirements
```

## Audit Execution

### Step 1: Read Everything
- Read the ENTIRE SRD (do not skim)
- Read the codebase files referenced by the SRD
- Read any comparison docs or existing specs mentioned

### Step 2: Audit Each Section
For each section of the SRD, check against all 7 categories. Be exhaustive.

### Step 3: Compile Report

```markdown
# SRD Audit Report: {Initiative Name}

**SRD Version Audited**: {version}
**Audit Date**: {date}

## Summary
- P0 findings: N
- P1 findings: N
- P2 findings: N
- **Verdict**: PASS (proceed) / FAIL (must remediate P0/P1 first)

## Findings

### P0 - Critical (Must Fix Now)
[findings...]

### P1 - Significant (Must Fix Now)
[findings...]

### P2 - Minor (Can Defer)
[findings...]
```

### Step 4: Remediate
- Fix ALL P0 and P1 findings directly in the SRD
- P2 findings: fix or document as known issues
- Update the SRD revision history after fixes

## AI Execution Pattern

```
# Launch multiple auditors in parallel (one per section group)
Agent: architect-reviewer
Prompt: "Read the ENTIRE SRD at [path]. Also read [codebase files].
         Audit for: feature gaps, factual mistakes, diagram errors,
         competing requirements, reuse opportunities, spec quality,
         additional concerns. For each finding:
         [CATEGORY] [SEVERITY] Location | Finding | Recommendation.
         Be exhaustive. Check every diagram. Cross-reference every
         claim against the actual codebase."

# Then fix findings
Agent: technical-writer
Prompt: "Fix these P0/P1 audit findings in the SRD: [list].
         Update the revision history."
```

## HITL Gate 2: SRD Sign-Off

After remediating all P0/P1 findings, you MUST present the SRD and audit results to the user for review before proceeding.

**Gate Protocol:**
1. Present a concise summary:
   - Total requirement count and breakdown by priority (Must/Should/Could)
   - Key architecture decisions made
   - Risks identified and their mitigations
   - Audit findings resolved (P0: N, P1: N, P2: N deferred)
   - Any open P2 items the user should be aware of
2. Explicitly ask: *"Do you approve this SRD and want to proceed to ticket creation, or do you have changes?"*
3. **STOP and WAIT** — do not proceed to Phase 4 autonomously
4. If the user requests changes, revise the SRD and re-present
5. Only proceed after receiving explicit sign-off

**What the user might change at this gate:**
- Add or remove requirements
- Change priorities (Must/Should/Could)
- Challenge architecture decisions
- Request additional sections (security, compliance, etc.)
- Flag requirements that seem untestable or vague
- Escalate deferred P2 findings to P1

## Next Phase

Once the user signs off at HITL Gate 2, proceed to Phase 4: Ticket Pack Creation (`/edm-ticket-pack`).
