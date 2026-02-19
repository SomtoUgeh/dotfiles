---
name: workflows:brainstorm
description: Shape a feature through collaborative R/S/fit-check dialogue before planning implementation
argument-hint: "[feature idea or problem to explore]"
---

# Shape a Feature or Improvement

**Note: The current year is 2026.** Use this when dating brainstorm documents.

Shaping answers **WHAT** to build through structured R/S/fit-check dialogue. It precedes `/workflows:plan`, which answers **HOW** to build it.

Load the `/shaping` skill as methodology reference throughout this workflow.

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

**If the feature description above is empty, ask the user:** "What would you like to explore? Please describe the feature, problem, or improvement you're thinking about."

Do not proceed until you have a feature description from the user.

## Execution Flow

### Phase 0: Assess Requirements Clarity

Evaluate whether brainstorming is needed based on the feature description.

**Clear requirements indicators:**
- Specific acceptance criteria provided
- Referenced existing patterns to follow
- Described exact expected behavior
- Constrained, well-defined scope

**If requirements are already clear:**
Use **AskUserQuestion tool** to suggest: "Your requirements seem detailed enough to proceed directly to planning. Should I run `/workflows:plan` instead, or would you like to shape the idea further?"

### Phase 1: Frame the Problem

#### 1.1 Repository Research (Lightweight)

Run a quick repo scan to understand existing patterns:

- Task repo-research-analyst("Understand existing patterns related to: <feature_description>")

Focus on: similar features, established patterns, CLAUDE.md guidance.

#### 1.2 Collaborative Framing

Use the **AskUserQuestion tool** to gather the Frame — one question at a time; interview me relentlessly until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one

**Capture verbatim:**
- **Source** — Original requests, quotes, or material that prompted the work (preserve exact wording)

**Distill collaboratively:**
- **Problem** — What's broken, what pain exists (distilled from source)
- **Outcome** — What success looks like (high-level, not solution-specific)

This is the shaping "Frame" — the "why" before any solution work begins.

### Phase 2: Populate R (Requirements)

Gather requirements via **AskUserQuestion tool**, one at a time.

**Rules:**
- Each R gets an ID: R0, R1, R2...
- Each R gets a description and status: Core goal, Must-have, Nice-to-have, Undecided, Out
- Max 9 top-level Rs — chunk with sub-reqs (R3.1, R3.2) if exceeding
- **R states the need, NOT the solution** — satisfaction is shown in fit check

**Exit condition:** Continue until user says "proceed" or requirements feel complete.

Display the full R table after each addition:

```markdown
| ID | Requirement | Status |
|----|-------------|--------|
| R0 | ... | Core goal |
| R1 | ... | Must-have |
```

### Phase 3: Sketch Shapes

Propose **2-3 shapes** (A, B, C) with parts tables.

**Rules:**
- Each shape gets a short descriptive title
- Each part = mechanism (what we BUILD), not intention
- Parts should be vertical slices, not horizontal layers
- Flag unknowns with ⚠️ in the Flag column

**Format per shape:**

```markdown
## A: [Short descriptive title]

| Part | Mechanism | Flag |
|------|-----------|:----:|
| A1 | [concrete mechanism] | |
| A2 | [mechanism with unknown] | ⚠️ |
```

Lead with your recommendation and explain why.

### Phase 4: Fit Check

Build a single R x S matrix — binary ✅/❌ only.

**Rules:**
- Always show full requirement text, never abbreviate
- Flagged unknowns (⚠️) → ❌ in fit check (can't claim what you don't know)
- No inline commentary in shape columns — explanations go in Notes
- If shape passes all checks but feels wrong → missing R, add it

```markdown
## Fit Check

| Req | Requirement | Status | A | B | C |
|-----|-------------|--------|---|---|---|
| R0 | [full text] | Core goal | ✅ | ✅ | ✅ |
| R1 | [full text] | Must-have | ✅ | ❌ | ✅ |

**Notes:**
- B fails R1: [brief explanation]
```

### Phase 5: Select Shape

Use **AskUserQuestion tool** to pick winning shape based on fit check.

**Options to present:**
- Pick one of the proposed shapes
- Compose from prior parts (e.g., "Shape D = A1 + B2 + C3-A")
- Refine further before deciding

**After selection:**
- Call out remaining flagged unknowns (⚠️) in the selected shape
- Suggest spikes if unknowns need investigation before planning

### Phase 6: Folder Name

Before writing the brainstorm document, determine the plan folder name:

- [ ] Determine type: feat, fix, refactor
- [ ] Create folder name: `YYYY-MM-DD-<type>-<descriptive-kebab-name>`
  - Example: `feat: Add User Authentication` → `2026-01-21-feat-user-authentication/`
  - Keep it descriptive (3-5 words) so plans are findable by context

This folder will later contain spec.md and prd.json when `/workflows:plan` runs.

### Phase 7: Capture the Shaping

Write brainstorm document to `docs/plans/YYYY-MM-DD-<type>-<name>/brainstorm.md`.

**Create the folder first:**
```bash
mkdir -p docs/plans/YYYY-MM-DD-<type>-<name>
```

**Document structure:**

```markdown
---
shaping: true
title: [Feature Title]
type: [feat|fix|refactor]
date: YYYY-MM-DD
status: brainstorm
---

# [Feature Title]

## Frame

### Source

> [Verbatim source material — user requests, quotes, messages]

### Problem

[What's broken, what pain exists]

### Outcome

[What success looks like]

## Requirements (R)

| ID | Requirement | Status |
|----|-------------|--------|
| R0 | [requirement text] | Core goal |
| R1 | [requirement text] | Must-have |
| R2 | [requirement text] | Nice-to-have |

## Shapes

### A: [Descriptive Title]

| Part | Mechanism | Flag |
|------|-----------|:----:|
| A1 | [mechanism] | |
| A2 | [mechanism] | ⚠️ |

### B: [Descriptive Title]

| Part | Mechanism | Flag |
|------|-----------|:----:|
| B1 | [mechanism] | |

## Fit Check

| Req | Requirement | Status | A | B |
|-----|-------------|--------|---|---|
| R0 | [full text] | Core goal | ✅ | ✅ |
| R1 | [full text] | Must-have | ✅ | ❌ |

**Notes:**
- B fails R1: [brief explanation]

## Selected Shape

> **Shape [X]: [Title]** selected based on fit check.

**Unresolved:**
- [Any remaining ⚠️ flagged unknowns]
- [Suggested spikes if needed]

## Open Questions

- [Question 1]

## Next Steps

Run `/workflows:plan` to create spec.md and prd.json in this folder.
```

### Phase 8: Handoff

Use **AskUserQuestion tool** to present next steps:

**Question:** "Brainstorm captured at `docs/plans/YYYY-MM-DD-<type>-<name>/brainstorm.md`. What would you like to do next?"

**Options:**
1. **Proceed to planning** - Run `/workflows:plan` (will auto-detect this brainstorm)
2. **Refine design further** - Continue shaping
3. **Done for now** - Return later

## Output Summary

When complete, display:

```
Shaping complete!

Folder: docs/plans/YYYY-MM-DD-<type>-<name>/
  brainstorm.md  ← created (shaping format)

Requirements: [count] Rs defined
Selected shape: [letter]: [title]
Unresolved: [count flagged unknowns or "none"]

Next: Run `/workflows:plan` to create spec.md and prd.json
```

## Important Guidelines

- **Stay focused on WHAT, not HOW** — Implementation details belong in the plan
- **Ask one question at a time** — Don't overwhelm
- **Apply YAGNI** — Prefer simpler approaches
- **R states need, S states mechanism** — Avoid tautologies
- **Parts must be vertical slices** — Not horizontal layers
- **Show full tables** — Never summarize or abbreviate R or S tables
- **Mark changes with 🟡** — When re-rendering tables after changes
- **Use the final folder name** — Same folder will hold spec.md and prd.json later

NEVER CODE! Just shape and document decisions.
