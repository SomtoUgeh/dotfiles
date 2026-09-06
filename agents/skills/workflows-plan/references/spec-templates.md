# Spec templates

### 4. Generate Spec(s) by Detail Level

Use the detail level chosen in Step 1.7. Simpler is mostly better.

#### MINIMAL (Quick Spec)

**Best for:** Simple bugs, small improvements, clear features

**Includes:**

- Problem statement or feature description
- Basic acceptance criteria
- Essential context only

**Structure:**

````markdown
---
title: [Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
---

# [Title]

## Problem

[Brief problem/feature description]

## Solution

[High-level approach]

## Acceptance Criteria

- [ ] Core requirement 1
- [ ] Core requirement 2

## Context

[Any critical information]

## References

- Similar pattern: `src/example.ts:42`
- Documentation: [relevant_docs_url]
````

#### STANDARD (Most Features)

**Best for:** Most features, complex bugs, team collaboration

**Includes everything from MINIMAL plus:**

- Detailed background and motivation
- Technical considerations
- Success metrics
- Dependencies and risks

**Structure:**

```markdown
---
title: [Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
---

# [Title]

## Overview

[Comprehensive description]

## Problem Statement

[Why this matters, what pain it solves]

## Proposed Solution

[High-level approach with rationale]

## Technical Considerations

- Architecture impacts
- Performance implications
- Security considerations

## Acceptance Criteria

- [ ] Detailed requirement 1
- [ ] Detailed requirement 2
- [ ] Testing requirements

## Success Metrics

[How we measure success]

## Dependencies & Risks

[What could block or complicate this]

## References

- Similar pattern: `src/services/example.ts:42`
- Best practices: [documentation_url]
- Related PR: #[pr_number]
```

#### COMPREHENSIVE (Major Features)

**Best for:** Major features, architectural changes, complex integrations spanning backend + frontend

**Produces a consolidating spec.md plus applicable detail documents.** Omit surfaces the feature does not have and list only actual files in the overview:

1. **adr.md** — Architecture Decision Record: every significant decision, who made it, why, alternatives rejected
2. **backend.md** — Backend Tech Spec: data model, API design, business logic, security, testing
3. **dtos.md** — DTO Contract Spec: shared + feature-specific request/response types with example payloads
4. **ui-design.md** — UI Design Tech Spec: page layouts, component inventory, responsive behavior, accessibility
5. **frontend.md** — Frontend Tech Spec: routing, state management, data fetching, forms, error handling, testing

**Decision Cascade Model:**

Every decision falls into one of three categories:

- **USER DECIDES** — Requires judgment, taste, or domain knowledge. Present 2-4 options with pros/cons tied to specific requirements, a recommendation with concrete rationale. Use **structured user-question tool**, one decision at a time. Wait for answer before proceeding.
- **LLM DERIVES** — Details constrained by an accepted decision and existing contracts. Record the relationship. Cursor pagination alone does not determine encoding, limits, API naming, or UI: derive those from project conventions or make their remaining tradeoffs explicit.
- **LLM DECIDES** — Routine details supported by project patterns and current authoritative guidance. Explain consequential tradeoffs; do not call a disputed design universal.

**Decision Queue** (ask in dependency order, skip what codebase already answers):

1. Data model shape and entity relationships
2. Status/enum definitions and state machines
3. API design (style, URL structure, endpoints)
4. Auth and permissions model for this feature
5. Frontend state management boundaries
6. Component architecture and granularity
7. Data fetching and cache strategy
8. Form management approach
9. UI interaction patterns (modals vs pages vs drawers)
10. Business logic placement (validation split, computation location)
11. Infrastructure decisions (background jobs, file storage, caching)

**Before asking questions:** Summarize conventions found in codebase, decisions already answered by existing patterns, decisions that don't apply, and roughly how many questions remain.

**After each decision:** Record it for ADR, derive cascading details immediately, confirm cascades briefly: "Got it — [choice]. That means I'll [cascade 1], [cascade 2]. Moving on to [next]."

**After necessary decisions:** Summarize choices and write applicable detail documents plus a consolidating spec.md. Do not re-ask for decisions the user already made.

**Consolidating spec.md (COMPREHENSIVE only):**

In addition to the 5 detailed docs, always produce a spec.md that serves as the entry point. This is what downstream tools (workflows-plan-review, workflows-deepen-plan, workflows-work) read first.

```markdown
---
title: [Title]
type: comprehensive
date: YYYY-MM-DD
documents:
  - adr.md
  - backend.md
  - dtos.md
  - ui-design.md
  - frontend.md
---

# [Title]

## Overview
[2-3 paragraph summary of the feature — problem, solution, key decisions]

## Key Architectural Decisions
[Consolidated from adr.md — the 3-5 most important decisions with rationale]

## API Surface
[Consolidated from backend.md + dtos.md — endpoints, key types, data flow]

## UI Approach
[Consolidated from ui-design.md + frontend.md — screens, states, interaction model]

## Acceptance Criteria
[Consolidated from all docs — the complete testable checklist]

## Technical Considerations
[Cross-cutting concerns: security, performance, deployment, risks]

## Detailed Documents
- [adr.md](adr.md) — Full architecture decision record
- [backend.md](backend.md) — Backend tech spec
- [dtos.md](dtos.md) — DTO contract spec
- [ui-design.md](ui-design.md) — UI design tech spec
- [frontend.md](frontend.md) — Frontend tech spec
```

This is NOT a thin index — it must contain enough substance that someone reading only spec.md understands the full plan. The 5 detailed docs are the deep-dive reference.

**Cross-reference before finalizing:**
- Every API endpoint has corresponding DTOs
- Every DTO is referenced by backend endpoint + frontend query/mutation
- Every component in UI design has wiring in frontend spec
- Every data field displayed in UI comes from a response DTO
- Server-side validation and authorization remain authoritative; client validation mirrors only rules needed for usable feedback and never exposes secret policy or replaces server checks
- Every decision in ADR is reflected in specs
