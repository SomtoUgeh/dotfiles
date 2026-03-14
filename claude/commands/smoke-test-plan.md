---
name: smoke-test-plan
description: Scan codebase and requirements to propose minimal high-value e2e smoke tests
argument-hint: "[optional: feature name, requirement doc path, or folder path]"
---

# Smoke Test Plan Generator

Scan the codebase and feature/requirement docs to propose a **small, high-value set of end-to-end smoke tests** — full user journeys only, not unit/integration-level cases.

These help answer: if we only ran a limited smoke suite after deploy, what should we run?

## Input

<input> #$ARGUMENTS </input>

- **If empty:** scan entire codebase and all requirement docs
- **If feature name:** prioritize that feature, still inspect surrounding flows it depends on
- **If file/folder path:** use as starting point, inspect related code
- **If ambiguous:** use AskUserQuestion

## What Counts as a Smoke Test

A smoke test = full end-to-end user journey covering a top-level business flow, executed from the user's POV, exercising multiple system layers. Failure would seriously reduce confidence in the release.

**Should:**
- Start from real entry point
- Include key UI interaction
- Traverse meaningful application logic
- Hit real integration boundaries
- Finish with meaningful business outcome visible to user

**Should not:**
- Assert a tiny isolated validation rule
- Test one helper function or hook in isolation
- Exhaustively test edge cases
- Cover permutations of filters/sorts/forms
- Duplicate what a unit or integration test should own

## Process

### Phase 1: Build Flow Inventory from Docs

Scan for requirement and feature docs. Look in `docs/` for any requirements, specs, plans, or feature docs. Extract:

- Feature summaries, user roles, user flows
- Acceptance criteria, business-critical actions
- Cross-feature dependencies, permissions/ownership rules

For each doc, identify: primary actor, core user goal, final successful outcome, what constitutes a meaningful e2e journey.

### Phase 2: Validate Flows Against Code

For each candidate flow from docs, inspect code to confirm:

- There is a real page/entry point
- User can actually perform the journey
- Flow is implemented across UI + backend
- Journey is not just a tiny sub-step
- Flow crosses enough system boundaries to be e2e-worthy

**What to inspect:** Route/page definitions, major forms, mutation hooks/endpoints, auth flow, feature entry pages, confirmation dialogs, navigation structure, major mutating endpoints, service methods for business actions, multi-step transactions, ownership checks.

### Phase 3: Discover Implicit Flows from Code

Look for important top-level flows not called out in docs but evident from product structure:

- Login/session establishment
- Onboarding/account setup
- Dashboard load
- Primary create/edit/purchase/submit flows
- Approval/review flows
- Logout/auth expiry recovery

### Phase 4: Classify Each Candidate

For every candidate flow, decide: **Smoke test**, **Better as integration test**, **Better as unit test**, or **Not worth testing directly**.

**Include flows that are:** business critical, revenue-critical, auth/session-critical, permission-critical, cross-system integration-critical, likely to catch catastrophic regressions, representative of major product capability.

**Exclude flows that are mainly:** field-level validation, edge-case-only, filter/sort permutations, minor visual states, tiny CRUD fragments, implementation detail checks.

### Phase 5: Select Minimal High-Value Suite

Choose the strongest set only. Default target: **5 to 10 smoke tests for the whole product**, fewer for a single feature. Do not force the count. Prefer golden paths first — only include negative-path smoke tests if truly high value (unauthorized access blocked, session expiry handled, insufficient funds blocks purchase).

### Phase 6: Write the Plan

Write to `docs/testing/smoke-test-plan.md` (or `docs/testing/smoke-test-plan-<feature-name>.md` for feature-specific scans).

## Output Structure

```markdown
# Smoke Test Plan

## Scope Scanned

- Requirements docs scanned:
  - `...`
- Code areas scanned:
  - `...`

## How Smoke Tests Were Chosen

[Brief explanation of selection logic]

## Candidate High-Level User Journeys

### 1. [Journey name]

- **Actor:** [User type]
- **Goal:** [What the user is trying to achieve]
- **Relevant docs:** [paths]
- **Relevant code areas:** [paths]
- **Why it matters:** [business/system value]
- **Classification:** Smoke test | Better as integration test | Better as unit test | Exclude
- **Reasoning:** [why]

[Repeat]

## Proposed Smoke Suite

### Smoke Test 1 -- [Journey name]

- **Priority:** Critical | High | Medium
- **Primary actor:** [User type]
- **Why this belongs in smoke:** [clear reasoning]
- **Journey summary:** [1-3 sentence summary]

#### Preconditions

- [Required setup]

#### High-Level Steps

1. [User-level action]
2. [User-level action]
3. [User-level action]
4. [Outcome validation]

#### What This Proves

- [Major system capability]
- [Integration boundaries exercised]
- [Critical regression types it would catch]

#### What This Deliberately Does Not Cover

- [Lower-level concerns left to unit/integration tests]

[Repeat for each selected smoke test]

## Flows Explicitly Excluded from Smoke

### [Flow]

- **Why excluded:** [better for unit/integration, too low-value, too brittle, duplicate coverage, etc.]

## Recommended Smoke Suite Size

- **Recommended number of smoke tests:** [N]
- **Reasoning:** [why this is the right size]

## Suggested Execution Order

1. [Most critical / quickest confidence]
2. [Next]
3. [Next]

## Risks / Gaps

- [Missing testability]
- [Hard environment setup]
- [Poor seed data assumptions]
- [Unclear requirements]
- [Observability gaps]
```

## Mandatory Rules

1. **Every proposed smoke test MUST be a full journey** — not "validate field X rejects negatives" but "user completes [business action] and sees [outcome]"
2. **Prefer golden paths first** — only include negative-path smoke tests if truly high value at product level
3. **Avoid combinatorial noise** — don't propose separate tests for every filter/sort variation; only include filtering if central to discovering entities in a critical journey
4. **Keep assertions high level** — visible final state, meaningful confirmation, resulting record visible in UI. Not DOM implementation detail or exact internal query behavior
5. **Avoid duplicate journeys** — if two tests exercise mostly the same capability, keep the stronger one
6. **Explicitly exclude lower-level flows** — for every excluded flow, explain what level of test is better

## Success Criteria

- Scanned both docs and code
- Identified major top-level user journeys
- Proposed a small, valuable set of smoke tests
- Every proposed smoke test is a real full user journey
- Low-level tests explicitly excluded from smoke
- Output is useful as a real smoke suite planning document
