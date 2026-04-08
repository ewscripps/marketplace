# AI-Assisted Development Methodology

**Version**: 2.0.0
**Status**: Active
**Purpose**: A structured, language-agnostic methodology for taking any software initiative from concept to shipped code
using AI-assisted parallel execution

---

## Overview

This document defines a six-phase development methodology for shipping complex software features with high confidence.
It is designed for AI-assisted execution using Claude Code with parallel agent swarms, but every phase and artifact
applies equally to human-led teams.

The methodology is **language-agnostic** and **project-agnostic**. It works for:

- Web services (Python, Go, Java, TypeScript, Rust, etc.)
- Desktop applications (Electron, Tauri, Qt, native)
- Mobile apps (React Native, Flutter, SwiftUI, Kotlin)
- Infrastructure (Terraform, Kubernetes, Ansible)
- Data pipelines (Spark, Airflow, dbt)
- Libraries and SDKs
- Any codebase of any size

The core insight is that **the cost of planning is always lower than the cost of rework**. Six deliberate phases — each
producing a reviewable artifact — catch errors early when they are cheap to fix.

---

## The Six Phases

```
Phase 1        Phase 2      Phase 3       Phase 4           Phase 5          Phase 6
 Planning  -->   SRD    -->  Audit   --> Ticket Pack  -->  Audit   -->  Implementation
                Creation     (SRD)      Creation          (Tickets)     + QC Audit
                                                                        + Remediation
```

Each phase produces a specific artifact. No phase is skipped. Each phase's output is the input to the next.

### When to Use This Methodology

| Scenario                           | Recommended? | Notes                                     |
|------------------------------------|--------------|-------------------------------------------|
| New feature with 10+ files changed | Yes          | Full six phases                           |
| Large refactor or migration        | Yes          | SRD captures the before/after state       |
| New service or module              | Yes          | Architecture decisions need documentation |
| Bug fix (1-3 files)                | No           | Just fix it                               |
| Config change or dependency update | No           | Just do it                                |
| Exploratory prototype              | Partial      | Phase 1-2 only, skip audit loops          |

---

## Phase 1: Planning & Discovery

* **Input**: Business requirement, feature request, or strategic initiative
* **Output**: Scope definition, current-state assessment, decision on whether to proceed

### Activities

1. **Understand the existing system** — explore the codebase structure, read architecture docs, understand the component
   map and how things connect
2. **Identify the gap** — what exists today vs. what is needed; where is the delta?
3. **Define scope boundaries** — what is in scope, what is explicitly out of scope, what is deferred to a future
   initiative
4. **Identify constraints** — licensing restrictions, existing code ownership, regulatory requirements, platform
   limitations, team expertise
5. **Map dependencies** — what existing systems does this touch? What must be built first?
6. **Estimate complexity** — is this a 1-week effort or a 6-month initiative?

### Artifacts

- Scope statement (1-2 paragraphs)
- Component inventory (which files, modules, or services are affected)
- Constraint list (licensing, regulatory, platform, performance)
- Dependency map (what blocks what)
- Go/no-go decision

### AI Execution Pattern

```
Agent: Explore (very thorough)
Prompt: "Explore the codebase to understand [area]. Map all components,
         identify gaps vs [requirement]. Report what exists, what's missing,
         what constraints apply, and what's blocked."
```

---

## Phase 2: SRD Creation

* **Input**: Scope definition from Phase 1
* **Output**: Software Requirements Document (100-2000 lines)

### What an SRD Contains

Not every SRD needs every section. Choose the sections that apply to your initiative:

| Section                  | Purpose                                                   | When to Include                       |
|--------------------------|-----------------------------------------------------------|---------------------------------------|
| Executive Summary        | What, why, and the key capability delta                   | Always                                |
| Document Information     | Version, owner, reviewers, revision history               | Always                                |
| Purpose & Scope          | In/out of scope, definition of "done"                     | Always                                |
| Current State Assessment | What exists, what's strong, what's missing                | Always                                |
| Target Architecture      | Diagrams, data flow, component design, deployment models  | When architecture changes             |
| Feature Requirements     | Grouped by domain, with requirement IDs                   | Always                                |
| Security                 | Threat model, encryption, authentication, authorization   | When security-relevant                |
| Observability            | Metrics, logging, tracing, dashboards                     | When operational behavior changes     |
| Compliance               | Audit, regulatory, data retention                         | When compliance-relevant              |
| Performance Targets      | Measurable NFRs with measurement methodology              | When performance matters              |
| Migration Path           | Phased rollout with timeline and team sizing              | For large initiatives                 |
| Risks & Mitigations      | Identified risks with likelihood, impact, and mitigations | Always                                |
| Glossary                 | Domain terms defined                                      | When domain-specific language is used |

### Requirement ID Conventions

Choose a short, unique prefix per initiative. All requirements get sequential IDs:

| Example   | Initiative               |
|-----------|--------------------------|
| `AUTH-01` | Authentication overhaul  |
| `PERF-01` | Performance optimization |
| `MIGR-01` | Database migration       |
| `APP-01`  | Main features            |
| `API-01`  | API v2 redesign          |

### Quality Standards

- Every requirement has a **unique ID** (e.g., `AUTH-01`, `PERF-12`)
- Every requirement is **testable** — it has clear pass/fail criteria
- Architecture is illustrated with **diagrams** (Mermaid, PlantUML, ASCII — whatever renders in your repo)
- Requirements are **prioritized** (Must Have / Should Have / Could Have)
- **No vague language** — "fast" becomes "< 200ms p95 at 1000 QPS", "secure" becomes specific cipher suites or auth
  flows
- **Cross-references** to existing systems, files, APIs, and external docs
- **Appropriate length** — 800+ lines for a major initiative, 200+ for a focused feature, 50+ for a small change

### AI Execution Pattern

```
Agent: technical-writer or product-manager
Prompt: "Write a comprehensive SRD for [initiative]. Read [existing docs]
         for context and format. Cover sections: [list applicable sections].
         Target [N] lines. Use requirement IDs [PREFIX]-01 through [PREFIX]-NNN.
         Every requirement must be testable."
```

---

## Phase 3: SRD Audit

* **Input**: SRD from Phase 2
* **Output**: Audit report with categorized findings and severity levels

The SRD audit is the highest-leverage phase. Every error caught here saves 10x the effort of catching it during
implementation.

### Audit Categories

| Category                   | What to Check                                                                                               |
|----------------------------|-------------------------------------------------------------------------------------------------------------|
| **Feature Gaps**           | Missing requirements, unaddressed edge cases, parity gaps with existing systems                             |
| **Factual Mistakes**       | Wrong API names, incorrect library references, impossible claims about tools or platforms                   |
| **Diagram Errors**         | Syntax errors, logical flow errors, missing edges, orphan nodes, unlabeled connections                      |
| **Competing Requirements** | Conflicts with current codebase behavior, existing features, other specs, or platform limitations           |
| **Reuse Opportunities**    | Existing code, libraries, services, or patterns that should be leveraged instead of rebuilt                 |
| **Specification Quality**  | Untestable requirements, missing IDs, contradictions, vague language, missing priorities                    |
| **Additional Concerns**    | Licensing, accessibility, internationalization, backward compatibility, deployment impact, team skills gaps |

### Severity Levels

| Severity | Definition                                                                         | Action                                                                  |
|----------|------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| P0       | Blocks implementation, creates a security/legal issue, or is architecturally wrong | Must fix in the current phase before moving to the next                 |
| P1       | Significant gap, factual error, or missing requirement                             | Must fix in the current phase before moving to the next                 |
| P2       | Polish issue, edge case, or improvement                                            | Can be deferred — fix during Ticket Pack Creation or Implementation     |

### Audit Report Format

Each finding follows this structure:

```
[CATEGORY] [SEVERITY] Section X.Y | Specific finding | Recommendation
```

Example findings:

```
[FEATURE GAP] [P1] Section 6.2 | No requirement for what happens when credentials
expire while user is offline | Add requirement with max offline TTL and re-auth flow

[FACTUAL] [P0] Section 7.3 | Claims library X supports feature Y, but it does not
as of v3.2 | Replace with library Z or implement custom solution

[REUSE] [P2] Section 8.1 | Describes building a new retry mechanism, but the existing
shared/retry module already implements exponential backoff | Reference existing module
```

### Remediation

After the audit, fix ALL P0 and P1 findings in the SRD. P2 findings are fixed or documented as known issues. Update the
revision history.

### AI Execution Pattern

```
Agent: architect-reviewer (multiple in parallel, one per section group)
Prompt: "Read the ENTIRE SRD. Also read [comparison docs] and [relevant codebase files].
         Audit for: [all 7 categories]. For each finding report:
         [CATEGORY] [SEVERITY] Location | Finding | Recommendation.
         Be exhaustive. Check every diagram. Cross-reference every claim against
         the actual codebase."

Then: Fix all P0/P1 findings with a technical-writer agent.
```

---

## Phase 4: Developer Ticket Pack Creation

* **Input**: Audited SRD from Phase 3
* **Output**: Ticket index + epic files (one per epic)

### Ticket Pack Structure

```
docs/tickets/{initiative}/
  README.md              # Index: legend, phases, ticket tables, critical path, epic summary
  epics/
    01-{epic-name}.md    # Full tickets with AC, tech notes, out of scope
    02-{epic-name}.md
    ...
```

### README.md Contents

1. **Legend** — size/duration/story-point mapping, priority definitions
2. **Cross-Cutting Requirements** — what every ticket must include (e.g., tests, documentation updates, CI checks)
3. **Ticket Index** — one table per phase; columns: ID, Title, Epic, Size, Priority, Depends On, SRD Refs
4. **Critical Path** — diagram showing the dependency chain with color-coded phases (every node must have a color
   assigned)
5. **Epics Summary** — table mapping epic numbers to ticket counts and file links
6. **SRD Coverage Map** — every requirement ID mapped to its implementing ticket(s)

### Epic File Contents

Each epic file contains 3-7 tickets. Each ticket includes:

| Field                   | Description                                                                             |
|-------------------------|-----------------------------------------------------------------------------------------|
| **Title**               | Imperative verb phrase ("Implement retry logic for payment webhook delivery")           |
| **Field Table**         | Epic, Phase, Priority, Size, SRD Refs, Depends On, Target Components                    |
| **Description**         | 2-3 paragraphs: what is being built and why                                             |
| **Acceptance Criteria** | 6-12 checkboxes — specific, testable, no ambiguity                                      |
| **Technical Notes**     | Implementation hints: recommended libraries, file paths, patterns to follow, edge cases |
| **Out of Scope**        | What this ticket does NOT cover (prevents scope creep)                                  |

### Writing Good Acceptance Criteria

* Bad: "Authentication should work"
* Good: "POST /auth/login with valid credentials returns 200 with a JWT containing `sub`, `org_id`, and `exp` claims"
 

* Bad: "Performance should be acceptable"
* Good: "GET /api/users responds in < 200ms p95 under 500 concurrent connections (measured with k6 load test)"
    

* Bad: "Handle errors gracefully"
* Good: "When the database is unreachable, the service returns 503 with
`{ error: 'service_unavailable', retry_after: 30 }` and logs a structured error with correlation ID"

### Ticket Sizing

| Size | Duration  | Story Points | Guideline                                       |
|------|-----------|--------------|-------------------------------------------------|
| XS   | < 1 day   | 1            | Config change, small fix, one-file edit         |
| S    | 1-3 days  | 2-3          | Single function/component, clear path           |
| M    | 3-5 days  | 5            | Multi-file change, some design decisions        |
| L    | 1-2 weeks | 8-13         | New module/service, multiple integration points |
| XL   | 2+ weeks  | 13+          | **Must be decomposed** before starting          |

### Quality Standards

- Every SRD requirement maps to at least one ticket
- Every ticket maps to at least one SRD requirement
- No ticket is larger than L (XL tickets must be decomposed into smaller tickets)
- Critical path is explicitly identified and diagrammed
- Phase boundaries are clear — no ticket spans multiple phases
- Target: 40-60 tickets for a major initiative, 10-20 for a focused feature

### AI Execution Pattern

```
Agent: product-manager
Prompt: "Create a comprehensive developer ticket pack for [SRD file path].
         Read [existing ticket pack] as the format model.
         Create README.md index + one epic file per epic.
         Target [N] tickets across [M] epics and [P] phases.
         Every SRD requirement must map to at least one ticket.
         Every ticket must have 6-12 specific, testable acceptance criteria."
```

---

## Phase 5: Ticket Pack Audit

* **Input**: Ticket pack from Phase 4
* **Output**: Audit findings (typically lighter than SRD audit)

### What to Check

1. **Coverage** — is every SRD requirement mapped to a ticket? Are there orphan requirements?
2. **Sizing** — are sizes realistic? Any XL tickets that need decomposition?
3. **Dependencies** — are all cross-ticket dependencies declared? Are there circular dependencies?
4. **Critical path** — is it correct? Are there hidden dependencies that would change the critical path?
5. **Acceptance criteria quality** — are they specific and testable? Could a QC auditor pass/fail each one?
6. **Diagram correctness** — syntax valid, all nodes colored/labeled, no orphan nodes
7. **Consistency** — do ticket IDs in README tables match the IDs in epic files? Do SRD Refs match actual requirement
   IDs?

### AI Execution Pattern

```
Agent: architect-reviewer
Prompt: "Audit the ticket pack at [path]. Cross-reference against [SRD].
         Check: coverage, sizing, dependencies, critical path, AC quality,
         diagrams, consistency. Report every gap found."
```

---

## Phase 6: Implementation + QC Audit + Remediation

* **Input**: Audited ticket pack from Phase 5
* **Output**: Committed, reviewed code on a feature branch

### Implementation Pattern

1. **Identify parallelizable work** — group tickets by file/component independence. Tickets that touch different files
   can run in parallel.
2. **Launch agent swarm** — one agent per independent group, each running in an isolated environment (git worktree,
   branch, or fork)
3. **Merge as agents complete** — resolve conflicts, commit with descriptive messages referencing ticket IDs
4. **Launch next wave** — after prerequisite tickets merge, launch dependent tickets
5. **Repeat** until all tickets are implemented

### QC Audit Pattern

After implementation, launch a **QC audit swarm** — one auditor per epic group:

1. Read the epic file for acceptance criteria
2. Read the actual implemented code
3. Compare **every** AC checkbox against the code — does the code satisfy it?
4. Report findings: `[SEVERITY] TICKET-ID | FILE_PATH | SPECIFIC CRITERION NOT MET`
5. Verdict per ticket: **PASS** / **PARTIAL** / **FAIL**

### Remediation Pattern

1. Compile all QC findings into a prioritized task list
2. Group fixes by file/component independence
3. Launch fix agents in parallel
4. Commit fixes in batches with descriptive messages
5. **If findings existed**: re-run QC audit on affected tickets to verify fixes

### Post-Implementation Checks

Before considering the initiative complete:

- [ ] All tickets have a PASS verdict (no FAIL or PARTIAL)
- [ ] All P0 QC findings are resolved
- [ ] Code compiles and existing tests pass
- [ ] New code has no references to out-of-scope dependencies
- [ ] Documentation is updated (README, API docs, architecture docs)
- [ ] All files are committed on the feature branch

### AI Execution Pattern

```
# Implementation (parallel by file independence)
Agent: domain-appropriate developer (6-10 parallel, isolated environments)
Prompt: "Implement tickets [IDs]. Read the epic file for acceptance criteria.
         Read existing code before modifying. [Detailed instructions per ticket.]"

# QC Audit (parallel by epic group)
Agent: senior QC engineer (one per epic group)
Prompt: "Read the epic file. Read the actual implemented code. Compare every
         acceptance criterion against the code. Report:
         [SEVERITY] TICKET | FILE | CRITERION NOT MET.
         Verdict per ticket: PASS / PARTIAL / FAIL."

# Remediation (parallel by file group)
Agent: domain-appropriate developer (grouped by file independence)
Prompt: "Fix these QC findings: [list]. Read each file before modifying.
         Write complete implementations — no stubs."
```

---

## Phase Timing Guidelines

| Initiative Size        | Planning | SRD  | SRD Audit | Tickets | Ticket Audit | Implementation | Total         |
|------------------------|----------|------|-----------|---------|--------------|----------------|---------------|
| Small (10-20 tickets)  | 30 min   | 2 hr | 1 hr      | 1 hr    | 30 min       | 4-8 hr         | **1-2 days**  |
| Medium (30-50 tickets) | 1 hr     | 4 hr | 2 hr      | 3 hr    | 1 hr         | 12-24 hr       | **3-5 days**  |
| Large (50-85 tickets)  | 2 hr     | 8 hr | 4 hr      | 6 hr    | 2 hr         | 24-48 hr       | **5-10 days** |

These assume AI-assisted execution with parallel agent swarms. Human-only execution: multiply by 5-10x.

---

## Artifacts Checklist

At the end of the full cycle, the repository should contain:

```
docs/
  {initiative}-srd.md                    # Software Requirements Document
  tickets/
    {initiative}/
      README.md                          # Ticket pack index with coverage map
      epics/
        01-{epic}.md                     # Epic files with full ticket details
        02-{epic}.md
        ...
```

Plus the implementation itself — in whatever directory structure is appropriate for the project.

---

## Anti-Patterns

| Anti-Pattern                                 | Why It Fails                                                                    | Correct Approach                                                  |
|----------------------------------------------|---------------------------------------------------------------------------------|-------------------------------------------------------------------|
| Skip the SRD, go straight to tickets         | Tickets lack context; scope creeps; contradictions emerge during implementation | Always write the SRD first, even a short one                      |
| Skip the audit                               | Errors in the SRD propagate to every ticket and every line of code              | Always audit; the cost is low, the savings are high               |
| One monolithic implementation pass           | Context exhaustion, no parallelism, massive merge conflicts                     | Parallel execution in isolated environments                       |
| Fix QC findings without re-auditing          | New fixes introduce new bugs; regressions go undetected                         | Re-audit after P0 fixes; spot-check P1/P2                         |
| Vague acceptance criteria ("it should work") | Untestable; QC can't pass/fail; disputes about completeness                     | Specific: "Returns 429 after 5 failed attempts within 15 minutes" |
| Tickets without SRD requirement refs         | No traceability; orphan work; missed requirements; can't prove coverage         | Every ticket cites its SRD requirement IDs                        |
| Giant tickets (XL / 2+ weeks)                | Too much scope; too many decisions; hard to review; blocks other work           | Decompose to L or smaller before starting                         |

---

## Adapting to Your Project

### For smaller projects (< 10 tickets)

Compress Phases 2-5 into a single document: a "mini-SRD" that combines requirements, ticket list, and acceptance
criteria in one file. Skip the separate ticket pack. Still do the audit.

### For regulated industries (healthcare, finance, defense)

Add a compliance review gate between Phase 5 and Phase 6. The compliance team reviews the ticket pack before
implementation begins. Add traceability columns linking requirements to regulatory frameworks (HIPAA, PCI-DSS, FedRAMP,
etc.).

### For infrastructure-as-code projects

Replace "file paths" in acceptance criteria with "resource paths" (Terraform modules, Kubernetes manifests, Ansible
roles). The QC audit checks `terraform plan` output and drift detection instead of code files.

### For data/ML projects

Add a "Data Requirements" section to the SRD covering: data sources, schema, volume, freshness, privacy classification,
and model evaluation criteria. The QC audit includes model metric validation (not just code review).

---

## Revision History

| Version | Date       | Summary                                                                                                                                         |
|---------|------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| 1.0.0   | 2026-03-27 | Initial formalization from OpenWork Enterprise + Desktop Enterprise                                                                             |
| 2.0.0   | 2026-03-27 | Generalized to language/project-agnostic methodology. Removed OpenWork-specific references. Added adaptation guide for different project types. |
